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
      assert_includes headers, "Due · 1 Oct – 4 Oct"
      assert_includes headers, "Overdue now"
      assert_equal 1, headers.count("Overdue now")
      assert_empty headers.grep(/\AOverdue now ·/)

      cells = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
                                                         .find { |row| row[0] == "Ravi Rep" }
      value = ->(header) { cells[headers.index(header)] }
      assert_equal "1", value.call("Due · 1 Oct – 4 Oct")
      assert_equal "1", value.call("Due · 5 Oct – 11 Oct")
      assert_equal "2", value.call("Due · Total")
    end
  end

  test "a breakdown with too many columns falls back to a coarser unit, and says so" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      followup(Time.zone.local(2026, 2, 3, 10))
      sign_in_as(@ravi)

      get "/forefront/reports/followups", params: { period: "custom", from: "2026-01-01", to: "2026-12-31", breakdown: "day" }

      assert_response :success
      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      assert_equal 53, headers.grep(/\ADue · \d/).size
      assert_includes headers, "Due · 2 Feb – 8 Feb"
      assert_select "[data-breakdown-notice]", /by week instead/
      assert_select "select[name=breakdown] option[selected][value=week]"
    end
  end

  test "a breakdown too large even by quarter is dropped, and says so" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      followup(Time.zone.local(2026, 10, 2, 10))
      sign_in_as(@ravi)

      get "/forefront/reports/followups", params: { period: "custom", from: "0001-01-01", to: "9999-12-31", breakdown: "day" }

      assert_response :success
      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      assert_equal [ "Person", "Due", "Done on time", "Done late", "Overdue now", "Rescheduled" ], headers
      assert_select "[data-breakdown-notice]", /totals only/
    end
  end

  test "a breakdown within the limit shows no notice" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      sign_in_as(@ravi)

      get "/forefront/reports/followups", params: { breakdown: "day" }

      assert_select "table[data-report] thead th", text: "Due · 1 Oct"
      assert_select "[data-breakdown-notice]", count: 0
    end
  end

  test "rescheduled ignores events before the period or by someone else and lands in its bucket" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      change = { "scheduled_for" => [ 1.day.ago, Time.current ] }
      record = lambda do |actor, at|
        event = Forefront::AuditEvent.record!(actor: actor, action: "updated_followup", auditable: @lead, audited_changes: change)
        Forefront::AuditEvent.where(id: event.id).update_all(created_at: at)
      end
      record.call(@ravi, Time.zone.local(2026, 9, 30, 12))
      record.call(@otto, Time.zone.local(2026, 10, 7, 12))
      record.call(@ravi, Time.zone.local(2026, 10, 7, 12))
      sign_in_as(@manager)

      get "/forefront/reports/followups", params: { breakdown: "week" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      cells = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
                                                         .find { |row| row[0] == "Ravi Rep" }
      assert_equal "0", cells[headers.index("Rescheduled · 1 Oct – 4 Oct")]
      assert_equal "1", cells[headers.index("Rescheduled · 5 Oct – 11 Oct")]
      assert_equal "1", cells[headers.index("Rescheduled · Total")]
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
