require "test_helper"

class Forefront::DashboardTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  test "each role lands on its own dashboard" do
    sign_in_as(@rep)
    get "/forefront/"
    assert_select "h2", "My Day"

    sign_in_as(@manager)
    get "/forefront/"
    assert_select "h2", "Team"
    assert_select "a[href=?]", "/forefront/?tab=my_day", text: "My Day"

    get "/forefront/", params: { tab: "my_day" }
    assert_select "h2", "My Day"

    sign_in_as(@admin)
    get "/forefront/"
    assert_select "h2", "Company"
  end

  test "the filter bar offers the periods, the viewer's products and the people they can narrow to" do
    sign_in_as(@manager)
    get "/forefront/"

    assert_select "select[name=period] option", count: 6
    assert_select "select[name=member_id] option", text: "Ravi Rep"
    assert_select "select[name=manager_id]", count: 0

    sign_in_as(@admin)
    get "/forefront/"
    assert_select "select[name=manager_id] option", text: "Mona Manager"
    assert_select "select[name=product_id] option", text: "Widget"
  end

  test "a manager with no allocations of their own can filter by their team's products" do
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    Forefront::Lead.create!(title: "Widget deal", description: "D", customer: customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product)
    Forefront::Lead.create!(title: "Other deal", description: "D", customer: customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source)
    sign_in_as(@manager)

    get "/forefront/"
    assert_select "select[name=product_id] option", text: "Widget"
    assert_equal "2", metric(:pipeline, slice: "open")

    get "/forefront/", params: { product_id: @product.id }
    assert_select "select[name=product_id] option[selected]", text: "Widget"
    assert_equal "1", metric(:pipeline, slice: "open")
  end

  test "filters and slices sent as lists instead of single values are ignored" do
    sign_in_as(@admin)

    get "/forefront/", params: { product_id: [ @product.id.to_s ], manager_id: [ @manager.id.to_s ], member_id: [ @rep.id.to_s ] }
    assert_response :success
    assert_select "select[name=product_id] option[selected]", count: 0

    Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", period: "monthly",
                              goal_value: 10_000, starts_on: Date.current.beginning_of_month)
    get "/forefront/dashboard/metrics/target_credit", params: { slice: [ "x" ] }
    assert_response :success
    assert_select "table[data-records]"
  end

  test "the old company-wide tiles are gone, so a sales person sees no one else's totals" do
    sign_in_as(@rep)
    get "/forefront/"

    assert_no_match "Total Tickets", response.body
    assert_no_match "Leaderboard", response.body
  end
end
