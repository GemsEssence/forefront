require "test_helper"

class Forefront::Performance::TargetsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @ravi
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  test "target achievement uses won amounts; collected vs target uses receipts" do
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "amount", period: "monthly", goal_value: 10_000,
                              starts_on: Date.current.beginning_of_month)
    lead = Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, product: @product, status: "won", actual_amount: 5_000)
    payment = Forefront::Payment.create!(lead: lead, total_amount: 5_000)
    Forefront::Receipt.create!(payment: payment, amount: 2_000, received_on: Date.current, payment_method: "cash", recorded_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "50%", cell("Ravi Rep", "target_achievement")
    assert_equal "20%", cell("Ravi Rep", "collected_vs_target")
    assert_equal "—", cell("Mona Manager", "target_achievement")
    assert_match "Won", drill(:target_credited, member_id: @ravi.id).first
  end

  test "a lead-count Target alone does not count" do
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "lead_count", period: "monthly", goal_value: 4,
                              starts_on: Date.current.beginning_of_month)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "—", cell("Ravi Rep", "target_achievement")
    assert_equal "—", cell("Ravi Rep", "collected_vs_target")
  end

  test "the drill for target_credited ignores lead-count Targets" do
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "lead_count", period: "monthly", goal_value: 4,
                              starts_on: Date.current.beginning_of_month)
    won_lead("Counted", @ravi, @product, 1_000)
    sign_in_as(@manager)

    assert_empty drill(:target_credited, member_id: @ravi.id)
    assert_response :success
  end

  test "targets are summed before dividing, and lead-count Targets are ignored" do
    gadget = Forefront::Product.create!(name: "Gadget")
    gadget.admins << @ravi
    start = Date.current.beginning_of_month
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "amount", period: "monthly", goal_value: 10_000, starts_on: start)
    Forefront::Target.create!(admin: @ravi, product: gadget, metric: "amount", period: "monthly", goal_value: 2_000, starts_on: start)
    gizmo = Forefront::Product.create!(name: "Gizmo")
    gizmo.admins << @ravi
    Forefront::Target.create!(admin: @ravi, product: gizmo, metric: "lead_count", period: "monthly", goal_value: 1, starts_on: start)
    won_lead("Gizmo win", @ravi, gizmo, 9_000)
    won_lead("Widget win", @ravi, @product, 3_000)
    won_lead("Gadget win", @ravi, gadget, 1_500)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "38%", cell("Ravi Rep", "target_achievement") # 4,500 / 12,000 = 37.5%
  end

  test "a team row combines everyone's achieved and goal" do
    pia = dashboard_staff("Pia Rep", "sales_person", manager: @manager)
    @product.admins << pia
    start = Date.current.beginning_of_month
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "amount", period: "monthly", goal_value: 10_000, starts_on: start)
    Forefront::Target.create!(admin: pia, product: @product, metric: "amount", period: "monthly", goal_value: 2_000, starts_on: start)
    won_lead("Ravi win", @ravi, @product, 1_000)
    won_lead("Pia win", pia, @product, 2_000)

    scope = Forefront::Dashboard::Scope.new(@manager, period: Forefront::Dashboard::Period.from_params({}), manager_id: @manager.id)

    assert_in_delta 25.0, Forefront::Performance.new(scope).value_target_achievement(scope), 0.001 # 3,000 / 12,000
  end

  private

  def won_lead(title, owner, product, amount)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                            source: forefront_source, product: product, status: "won", actual_amount: amount)
  end
end
