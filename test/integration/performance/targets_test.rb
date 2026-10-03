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
end
