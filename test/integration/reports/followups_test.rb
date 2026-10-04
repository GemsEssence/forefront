require "test_helper"

class Forefront::Reports::FollowupsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source)
  end

  def followup(at, status: "pending", completed_at: nil, owner: @ravi)
    @lead.followups.create!(assigned_to: owner, created_by: owner, followup_type: "call", scheduled_for: at, status: status, completed_at: completed_at)
  end

  test "per person: due, on time, late, overdue now and reschedules; other teams excluded" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      followup(Time.zone.local(2026, 10, 3, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 3, 18))
      followup(Time.zone.local(2026, 10, 4, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 6, 9))
      followup(Time.zone.local(2026, 10, 5, 10))
      followup(Time.zone.local(2026, 10, 5, 10), owner: @otto)
      Forefront::AuditEvent.record!(actor: @ravi, action: "updated_followup", auditable: @lead, audited_changes: { "scheduled_for" => [ 1.day.ago, Time.current ] })
      Forefront::AuditEvent.record!(actor: @ravi, action: "updated_followup", auditable: @lead, audited_changes: { "outcome" => [ nil, "ok" ] })
      sign_in_as(@manager)

      get "/forefront/reports/followups"

      rows = css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
      assert_equal [ "3", "1", "1", "1", "1" ], rows["Ravi Rep"]
      assert_nil rows["Otto Outsider"]
    end
  end

  test "agrees with the dashboard definitions and excludes followups just outside the period" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      followup(Time.zone.local(2026, 10, 3, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 3, 18))
      followup(Time.zone.local(2026, 10, 5, 10), status: "cancelled")
      followup(Time.zone.local(2026, 10, 5, 10))
      followup(Time.zone.local(2026, 9, 27, 23), status: "completed", completed_at: Time.zone.local(2026, 9, 28, 1))
      followup(Time.zone.local(2026, 10, 25, 10))
      sign_in_as(@manager)

      get "/forefront/reports/followups"

      scope = Forefront::Dashboard::Scope.from_params(@manager, ActionController::Parameters.new, own: false).for_member(@ravi)
      due = Forefront::Dashboard::Metrics.fetch(:followups_due).relation(scope).count
      on_time = Forefront::Dashboard::Metrics.fetch(:followups_on_time).relation(scope).count
      overdue = Forefront::Dashboard::Metrics.fetch(:overdue_followups).relation(scope).count
      rows = css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
      assert_equal [ due, on_time, 0, overdue ].map(&:to_s), rows["Ravi Rep"].first(4)
      assert_equal "2", rows["Ravi Rep"][0]
    end
  end

  test "breakdown by week splits due counts into week columns" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      followup(Time.zone.local(2026, 10, 2, 10))
      followup(Time.zone.local(2026, 10, 8, 10))
      sign_in_as(@manager)

      get "/forefront/reports/followups", params: { breakdown: "week" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      assert_includes headers, "Due · 28 Sep – 4 Oct"
      assert_includes headers, "Overdue now"
    end
  end
end

class Forefront::Reports::FollowupsQueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  def queries_for(path, params)
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path, params: params }
    assert_response :success
    count
  end

  test "the number of queries does not grow with the people or the buckets" do
    manager = dashboard_staff("Mona Manager", "manager")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: manager, assigned_to: manager, source: forefront_source)
    add = lambda do |name|
      rep = dashboard_staff(name, "sales_person", manager: manager)
      lead.followups.create!(assigned_to: rep, created_by: rep, followup_type: "call", scheduled_for: 3.days.ago)
      Forefront::AuditEvent.record!(actor: rep, action: "updated_followup", auditable: lead, audited_changes: { "scheduled_for" => [ 1.day.ago, Time.current ] })
    end
    add.call("Rep 0")
    sign_in_as(manager)
    few = queries_for("/forefront/reports/followups", { breakdown: "day", period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    5.times { |i| add.call("Rep #{i + 1}") }
    many = queries_for("/forefront/reports/followups", { breakdown: "day", period: "custom", from: 30.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    assert_operator (many - few).abs, :<=, 2
  end
end
