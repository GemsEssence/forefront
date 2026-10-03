require "test_helper"

class Forefront::Dashboard::ActionStripTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @outsider = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, owner)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner, source: forefront_source)
  end

  def followup(on, owner, at)
    on.followups.create!(assigned_to: owner, created_by: owner, followup_type: "call", scheduled_for: at)
  end

  test "overdue and due-today followups, and newly assigned work, each open their list" do
    big = lead("Big Deal", @rep)
    followup(big, @rep, 2.hours.ago)
    followup(big, @rep, Time.current.end_of_day - 1.second) # later today
    followup(lead("Otto's", @outsider), @outsider, 2.hours.ago)
    big.assignments.create!(to_user: @rep, changed_by: @manager)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:overdue_followups)
    assert_equal "1", metric(:followups_due_today)
    assert_equal "1", metric(:newly_assigned)
    assert_equal 1, drill(:overdue_followups).size
    assert_match "Big Deal", drill(:overdue_followups).first
    assert_match "Ravi Rep", drill(:newly_assigned).first
  end

  test "newly assigned compares with the previous period" do
    travel_to Time.zone.local(2026, 10, 15, 12)
    big = lead("Big Deal", @rep)
    big.assignments.create!(to_user: @rep, changed_by: @manager)
    big.assignments.create!(to_user: @rep, changed_by: @manager, created_at: 1.month.ago)
    big.assignments.create!(to_user: @rep, changed_by: @manager, created_at: 1.month.ago)
    sign_in_as(@rep)

    get "/forefront/"

    strip = widget("action_strip")
    assert_equal "1", css_select(strip, "[data-metric='newly_assigned']").first.text.squish
    assert_equal "▼ 50%", css_select(strip, "[data-change='newly_assigned']").first&.text&.squish
  end

  test "a sales person can't drill into someone else's records by naming them" do
    followup(lead("Otto's", @outsider), @outsider, 2.hours.ago)
    followup(lead("Ravi's", @rep), @rep, 2.hours.ago)
    sign_in_as(@rep)

    rows = drill(:overdue_followups, member_id: @outsider.id)

    assert_response :success
    assert_equal 1, rows.size
    assert_match "Ravi's", rows.first
    assert_no_match(/Otto's/, rows.join)
  end

  test "an unknown metric is not found" do
    sign_in_as(@rep)
    get "/forefront/dashboard/metrics/no_such_thing"
    assert_response :not_found
  end

  test "a role can't open a metric that isn't theirs" do
    Forefront::Dashboard::Metrics.define(:managers_only_probe, title: "Probe", kind: :followups, roles: %w[manager]) { |scope, _| scope.followups }
    sign_in_as(@rep)

    get "/forefront/dashboard/metrics/managers_only_probe"

    assert_redirected_to "/forefront/"
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end
end
