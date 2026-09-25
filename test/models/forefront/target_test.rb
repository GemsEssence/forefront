require "test_helper"

class Forefront::TargetTest < ActiveSupport::TestCase
  setup do
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
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

  test "amount target: achieved_value sums the actual amount of leads won in the period" do
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 150, period: "monthly", starts_on: Date.new(2026, 3, 1))

    create_won_lead(won_at: Time.utc(2026, 3, 10), amount: 100)
    create_won_lead(won_at: Time.utc(2026, 2, 28), amount: 900)
    create_won_lead(won_at: Time.utc(2026, 4, 1), amount: 900)
    Forefront::Lead.create!(title: "Open", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product, estimated_amount: 900)

    assert_equal 100, target.achieved_value
    assert_not target.achieved?
  end

  test "amount target: counts the actual amount, not the estimate or the payment" do
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 150, period: "monthly", starts_on: Date.new(2026, 3, 1))

    lead = create_won_lead(won_at: Time.utc(2026, 3, 10), amount: 200)
    Forefront::Payment.create!(lead: lead, total_amount: 50)

    assert_equal 5000, lead.estimated_amount
    assert_equal 200, target.achieved_value
  end

  test "lead_count target: achieved_value counts leads won in the period" do
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "lead_count", goal_value: 2, period: "monthly", starts_on: Date.new(2026, 3, 1))

    create_won_lead(won_at: Time.utc(2026, 3, 5))
    create_won_lead(won_at: Time.utc(2026, 3, 20))

    assert_equal 2, target.achieved_value
    assert target.achieved?
  end

  test "achieved_value only counts an admin's own share of a shared lead" do
    other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product.admins << other_rep
    target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 1))

    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product)
    Forefront::AssignmentOperations::Create.new(assignable: lead, params: { to_user_id: @rep.id, from_user_id: nil }, current_admin: @rep).call
    Forefront::AssignmentOperations::Create.new(assignable: lead, params: { to_user_id: other_rep.id }, current_admin: @rep).call
    lead.update!(status: "won", actual_amount: 100)
    lead.update_column(:won_at, Time.utc(2026, 3, 10))

    assert_equal 0, target.achieved_value, "rep was reassigned away and the lead isn't shared, so they get no credit yet"

    share = Forefront::LeadShare.new(lead: lead, recorded_by: @rep)
    share.lead_share_participants.build(admin: @rep, percentage: 40)
    share.lead_share_participants.build(admin: other_rep, percentage: 60)
    share.save!

    assert_equal 40, target.reload.achieved_value
  end

  private

  def create_won_lead(won_at:, amount: 100)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product, estimated_amount: 5000)
    lead.update!(status: "won", actual_amount: amount)
    lead.update_column(:won_at, won_at)
    lead
  end
end
