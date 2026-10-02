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

  test "the old company-wide tiles are gone, so a sales person sees no one else's totals" do
    sign_in_as(@rep)
    get "/forefront/"

    assert_no_match "Total Tickets", response.body
    assert_no_match "Leaderboard", response.body
  end
end
