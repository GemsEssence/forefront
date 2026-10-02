require "test_helper"

class Forefront::Dashboard::TargetsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", period: "monthly",
                                        goal_value: 10_000, starts_on: Date.current.beginning_of_month)
  end

  test "the target meter shows what's achieved, opens the credited leads, and the run rate needed" do
    Forefront::Lead.create!(title: "Won one", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product, status: "won", actual_amount: 4_000)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "₹4,000.00", metric(:target_credit, slice: @target.id)
    days_left = (Date.current.end_of_month - Date.current).to_i + 1
    assert_match "₹6,000.00 to go", widget("target_meter").text
    assert_match "#{format('%.2f', 6000.0 / days_left)}", widget("target_meter").text.delete(",")
    assert_match "Won one", drill(:target_credit, slice: @target.id).first
  end

  test "the team target totals each kind of target and shows each person's progress" do
    sign_in_as(@manager)

    get "/forefront/"

    assert_match "₹0.00 of ₹10,000.00", widget("team_target").text
    assert_match "Ravi Rep", widget("team_target").text
  end

  test "a target outside the viewer's scope can't be drilled into" do
    other = dashboard_staff("Otto Outsider", "sales_person")
    theirs = Forefront::Target.create!(admin: other, product: @product, metric: "lead_count", period: "monthly", goal_value: 3, starts_on: Date.current.beginning_of_month)
    @product.admins << other
    Forefront::Lead.create!(title: "Otto's win", description: "D", customer: @customer, created_by: other, assigned_to: other,
                            source: forefront_source, product: @product, status: "won", actual_amount: 500)
    sign_in_as(@rep)

    assert_empty drill(:target_credit, slice: theirs.id)
    assert_response :success
    assert_select "table[data-records]"
  end
end
