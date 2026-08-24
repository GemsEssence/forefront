require "test_helper"

class Forefront::TargetTest < ActiveSupport::TestCase
  setup do
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget", price: 100)
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "starts_on must be the calendar-aligned start of its period" do
    monthly_mid_month = Forefront::Target.new(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 15))
    monthly_aligned = Forefront::Target.new(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 1))
    quarterly_misaligned = Forefront::Target.new(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "quarterly", starts_on: Date.new(2026, 2, 1))
    quarterly_aligned = Forefront::Target.new(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "quarterly", starts_on: Date.new(2026, 4, 1))

    assert_not monthly_mid_month.valid?
    assert_includes monthly_mid_month.errors[:starts_on], "must be the first day of the month for a monthly target"
    assert monthly_aligned.valid?
    assert_not quarterly_misaligned.valid?
    assert quarterly_aligned.valid?
  end

  test "ends_on is derived from period" do
    monthly = Forefront::Target.new(period: "monthly", starts_on: Date.new(2026, 3, 1))
    quarterly = Forefront::Target.new(period: "quarterly", starts_on: Date.new(2026, 4, 1))
    half_yearly = Forefront::Target.new(period: "half_yearly", starts_on: Date.new(2026, 1, 1))
    yearly = Forefront::Target.new(period: "yearly", starts_on: Date.new(2026, 1, 1))

    assert_equal Date.new(2026, 3, 31), monthly.ends_on
    assert_equal Date.new(2026, 6, 30), quarterly.ends_on
    assert_equal Date.new(2026, 6, 30), half_yearly.ends_on
    assert_equal Date.new(2026, 12, 31), yearly.ends_on
  end

  test "amount target: achieved_value sums the product price of leads won in the period" do
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 150, period: "monthly", starts_on: Date.new(2026, 3, 1))

    won_in_period = create_won_lead(won_at: Time.utc(2026, 3, 10))
    won_before_period = create_won_lead(won_at: Time.utc(2026, 2, 28))
    won_after_period = create_won_lead(won_at: Time.utc(2026, 4, 1))
    still_open = Forefront::Lead.create!(title: "Open", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product)

    assert_equal 100, target.achieved_value
    assert_not target.achieved?
  end

  test "lead_count target: achieved_value counts leads won in the period" do
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "lead_count", goal_value: 2, period: "monthly", starts_on: Date.new(2026, 3, 1))

    create_won_lead(won_at: Time.utc(2026, 3, 5))
    create_won_lead(won_at: Time.utc(2026, 3, 20))

    assert_equal 2, target.achieved_value
    assert target.achieved?
  end

  private

  def create_won_lead(won_at:)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product)
    lead.update!(status: "won")
    lead.update_column(:won_at, won_at)
    lead
  end
end
