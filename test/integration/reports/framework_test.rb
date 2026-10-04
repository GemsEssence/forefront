require "test_helper"

class Forefront::Reports::FrameworkTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
  end

  test "the index lists the reports each role may open, and the sidebar links to it" do
    sign_in_as(@rep)
    get "/forefront/reports"
    assert_response :success
    assert_select "a[href='/forefront/reports/lead_stage']"
    assert_select "aside[data-sidebar] a[href='/forefront/reports']", "Reports"
  end

  test "an unknown report is not found" do
    sign_in_as(@admin)
    get "/forefront/reports/nope"
    assert_response :not_found
  end
end
