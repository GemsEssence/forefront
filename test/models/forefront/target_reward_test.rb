require "test_helper"

class Forefront::TargetRewardTest < ActiveSupport::TestCase
  setup do
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "reward_type and bonus_type must be fixed or percentage" do
    assert_raises(ArgumentError) { build_target(reward_type: "sometimes", reward_value: 50) }
  end

  test "a percentage reward_value over 100 is rejected" do
    target = build_target(reward_type: "percentage", reward_value: 150)
    assert_not target.valid?
    assert_includes target.errors[:reward_value], "must be less than or equal to 100"
  end

  test "a fixed reward_value over 100 is fine" do
    target = build_target(reward_type: "fixed", reward_value: 5000)
    assert target.valid?
  end

  test "reward_type requires a reward_value" do
    target = build_target(reward_type: "fixed", reward_value: nil)
    assert_not target.valid?
    assert_includes target.errors[:reward_value], "can't be blank"
  end

  test "no reward is paid when the target has not been met" do
    target = build_target!(goal_value: 1000, metric: "amount", reward_type: "fixed", reward_value: 50)
    win_lead(won_at: Time.utc(2026, 3, 5))

    assert_equal 0, target.reward_amount
  end

  test "a fixed reward is paid once the target is met" do
    target = build_target!(goal_value: 100, metric: "amount", reward_type: "fixed", reward_value: 25)
    win_lead(won_at: Time.utc(2026, 3, 5))

    assert target.achieved?
    assert_equal 25, target.reward_amount
  end

  test "a percentage reward is computed against the goal, not the deal revenue" do
    target = build_target!(goal_value: 100, metric: "amount", reward_type: "percentage", reward_value: 10)
    win_lead(won_at: Time.utc(2026, 3, 5))
    win_lead(won_at: Time.utc(2026, 3, 10))

    assert_equal 200, target.achieved_value
    assert_equal 10, target.reward_amount
  end

  test "a bonus is only paid once the target is exceeded, on top of the reward" do
    target = build_target!(goal_value: 100, metric: "amount", reward_type: "fixed", reward_value: 25, bonus_type: "fixed", bonus_value: 40)
    win_lead(won_at: Time.utc(2026, 3, 5))

    assert_equal 0, target.bonus_amount
    assert_equal 25, target.total_payout

    win_lead(won_at: Time.utc(2026, 3, 10))

    assert_equal 40, target.bonus_amount
    assert_equal 65, target.total_payout
  end

  test "missed? is true only once the period has ended without the goal being met" do
    target = build_target!(goal_value: 1000, metric: "amount", starts_on: Date.new(2020, 1, 1), period: "monthly")

    assert target.missed?

    target.update!(starts_on: 1.month.from_now.beginning_of_month)
    assert_not target.missed?
  end

  private

  def build_target(overrides = {})
    Forefront::Target.new({
      admin: @rep, product: @product, metric: "amount", goal_value: 1000,
      period: "monthly", starts_on: Date.new(2026, 3, 1)
    }.merge(overrides))
  end

  def build_target!(overrides = {})
    build_target(overrides).tap(&:save!)
  end

  def win_lead(won_at:, amount: 100)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open", product: @product)
    lead.update!(status: "won", actual_amount: amount)
    lead.update_column(:won_at, won_at)
    lead
  end
end
