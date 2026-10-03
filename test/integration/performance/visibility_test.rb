require "test_helper"

class Forefront::Performance::VisibilityTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
  end

  test "a sales person sees only their own row, titled My performance, with no sort links" do
    sign_in_as(@ravi)

    get "/forefront/performance"

    assert_response :success
    assert_select "h2", "My performance"
    assert_equal [ "Ravi Rep" ], row_labels
    assert_select "thead a[href*='sort=']", count: 0
  end

  test "a manager sees their reports and themselves, and no outsiders" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_select "h2", "Performance"
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels.sort
  end

  test "a member filter outside the viewer's scope is ignored" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { member_id: @otto.id }

    assert_not_includes row_labels, "Otto Outsider"
  end

  test "a sales person cannot widen their view with member_id or manager_id" do
    sign_in_as(@ravi)

    get "/forefront/performance", params: { member_id: @otto.id }
    assert_response :success
    assert_equal [ "Ravi Rep" ], row_labels

    get "/forefront/performance", params: { manager_id: @manager.id }
    assert_response :success
    assert_equal [ "Ravi Rep" ], row_labels
  end

  test "an admin can open the page and sees the people rows" do
    sign_in_as(@admin)

    get "/forefront/performance"

    assert_response :success
    assert_select "h2", "Performance"
    assert_operator row_labels.size, :>, 0
  end

  test "the sidebar links to it for every role" do
    sign_in_as(@ravi)
    get "/forefront/"
    assert_select "aside[data-sidebar] a[href='/forefront/performance']", "My performance"

    sign_in_as(@manager)
    get "/forefront/"
    assert_select "aside[data-sidebar] [data-nav-group='Team'] a[href='/forefront/performance']", "Performance"
  end
end
