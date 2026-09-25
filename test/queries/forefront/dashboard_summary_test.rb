require "test_helper"

class Forefront::DashboardSummaryTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @product.admins << @other_rep
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "total_revenue only counts fully paid payments, scoped to visible admins" do
    win_and_pay(@rep, amount: 300, paid: true)
    win_and_pay(@rep, amount: 200, paid: false)
    win_and_pay(@other_rep, amount: 500, paid: true)

    rep_summary = Forefront::DashboardSummary.new(@rep)
    assert_equal 300, rep_summary.total_revenue

    manager_summary = Forefront::DashboardSummary.new(@manager)
    assert_equal 300, manager_summary.total_revenue

    admin_summary = Forefront::DashboardSummary.new(@admin)
    assert_equal 800, admin_summary.total_revenue
  end

  test "revenue counts a payment split into fully paid installments, even though Payment#status itself never flips" do
    lead = win_lead(@rep)
    payment = Forefront::Payment.create!(lead: lead, total_amount: 100)
    installment = payment.installments.create!(amount: 100, due_on: Date.tomorrow)
    installment.update!(status: "paid", paid_at: Time.current)

    assert_equal "pending", payment.reload.status
    assert_equal 100, Forefront::DashboardSummary.new(@rep).total_revenue
  end

  test "target_summary buckets targets into achieved, missed, and in_progress for visible admins only" do
    Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 100, period: "monthly", starts_on: Date.new(2020, 1, 1))
    win_and_pay(@rep, amount: 100, paid: true, won_at: Time.utc(2020, 1, 15))
    Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2020, 2, 1))
    Forefront::Target.create!(admin: @other_rep, product: @product, metric: "amount", goal_value: 100, period: "monthly", starts_on: 1.month.from_now.beginning_of_month)

    summary = Forefront::DashboardSummary.new(@manager).target_summary

    assert_equal 1, summary[:achieved]
    assert_equal 1, summary[:missed]
    assert_equal 0, summary[:in_progress]
  end

  test "leaderboard ranks visible sales persons by revenue, highest first" do
    win_and_pay(@rep, amount: 300, paid: true)
    win_and_pay(@other_rep, amount: 500, paid: true)

    leaderboard = Forefront::DashboardSummary.new(@admin).leaderboard

    assert_equal [ @other_rep, @rep ], leaderboard.map { |row| row[:admin] }
    assert_equal [ 500, 300 ], leaderboard.map { |row| row[:revenue] }
  end

  test "total_revenue only counts wins within the given date range, when one is given" do
    win_and_pay(@rep, amount: 300, paid: true, won_at: Time.utc(2020, 1, 15))
    win_and_pay(@rep, amount: 700, paid: true, won_at: Time.utc(2020, 3, 15))

    summary = Forefront::DashboardSummary.new(@rep, from: Date.new(2020, 1, 1), to: Date.new(2020, 1, 31))

    assert_equal 300, summary.total_revenue
  end

  test "won_leads_count only counts wins within the given date range, when one is given" do
    win_lead(@rep, won_at: Time.utc(2020, 1, 15))
    win_lead(@rep, won_at: Time.utc(2020, 3, 15))

    summary = Forefront::DashboardSummary.new(@rep, from: Date.new(2020, 1, 1), to: Date.new(2020, 1, 31))

    assert_equal 1, summary.won_leads_count
  end

  test "leaderboard revenue only counts wins within the given date range, when one is given" do
    win_and_pay(@rep, amount: 300, paid: true, won_at: Time.utc(2020, 1, 15))
    win_and_pay(@other_rep, amount: 700, paid: true, won_at: Time.utc(2020, 3, 15))

    leaderboard = Forefront::DashboardSummary.new(@admin, from: Date.new(2020, 1, 1), to: Date.new(2020, 1, 31)).leaderboard

    assert_equal({ @rep => 300, @other_rep => 0 }, leaderboard.to_h { |row| [ row[:admin], row[:revenue] ] })
  end

  test "without a date range, totals remain all-time" do
    win_and_pay(@rep, amount: 300, paid: true, won_at: Time.utc(2020, 1, 15))
    win_and_pay(@rep, amount: 700, paid: true, won_at: Time.utc(2021, 3, 15))

    summary = Forefront::DashboardSummary.new(@rep)

    assert_equal 1000, summary.total_revenue
  end

  private

  def win_lead(rep, won_at: Time.current)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: rep, assigned_to: rep, source: "website", status: "open", product: @product)
    lead.update!(status: "won")
    lead.update_column(:won_at, won_at)
    lead
  end

  def win_and_pay(rep, amount:, paid:, won_at: Time.current)
    lead = win_lead(rep, won_at: won_at)
    status = paid ? "paid" : "pending"
    Forefront::Payment.create!(lead: lead, total_amount: amount, status: status, paid_at: (Time.current if paid))
    lead
  end
end
