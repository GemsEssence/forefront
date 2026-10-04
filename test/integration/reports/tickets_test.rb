require "test_helper"

class Forefront::Reports::TicketsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def ticket(category, created_at:, resolved_after: nil, lead: nil, by: @ravi)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: by, assigned_to: by,
                                       category: category, priority: "medium", status: "open", created_at: created_at, lead: lead)
    if resolved_after
      ticket.update_columns(status: "resolved")
      Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: "Resolved", changed_by: by, created_at: created_at + resolved_after)
    end
    ticket
  end

  def report_rows
    css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
  end

  test "per category: opened, resolved, hours to resolve and tickets per lead" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source)
    ticket("demo", created_at: 3.days.ago, resolved_after: 2.hours, lead: lead)
    ticket("demo", created_at: 2.days.ago, resolved_after: 4.hours, lead: lead)
    ticket("request", created_at: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/tickets"

    rows = report_rows
    assert_equal [ "2", "2", "3.0", "2.0" ], rows["Demo"]
    assert_equal [ "1", "0", "—", "—" ], rows["Request"]
  end

  test "tickets opened or resolved before the period are not counted and quiet categories are not listed" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ticket("demo", created_at: 60.days.ago, resolved_after: 1.hour)
      ticket("tech", created_at: 5.days.ago)
      sign_in_as(@manager)

      get "/forefront/reports/tickets"

      assert_equal [ "Tech" ], report_rows.keys
      assert_equal [ "1", "0", "—", "—" ], report_rows["Tech"]
    end
  end

  test "a ticket opened before the period but resolved in it counts as resolved only" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ticket("issue", created_at: 40.days.ago, resolved_after: 35.days)
      sign_in_as(@manager)

      get "/forefront/reports/tickets"

      assert_equal [ "0", "1", "840.0", "—" ], report_rows["Issue"]
    end
  end

  test "tickets of another team are excluded" do
    other = dashboard_staff("Olga Other", "manager")
    ticket("demo", created_at: 1.day.ago, by: other)
    ticket("tech", created_at: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/tickets"

    assert_equal [ "Tech" ], report_rows.keys
  end

  test "breakdown by week puts each week's opened tickets in its own column" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ticket("demo", created_at: Time.zone.local(2026, 10, 2, 9))
      ticket("demo", created_at: Time.zone.local(2026, 10, 3, 9))
      ticket("demo", created_at: Time.zone.local(2026, 10, 9, 9))
      sign_in_as(@manager)

      get "/forefront/reports/tickets", params: { breakdown: "week" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      demo = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }.find { |row| row[0] == "Demo" }
      assert_equal "2", demo[headers.index("Opened · 28 Sep – 4 Oct")]
      assert_equal "1", demo[headers.index("Opened · 5 Oct – 11 Oct")]
      assert_equal "3", demo[headers.index("Opened · Total")]
    end
  end
end

class Forefront::Reports::TicketsQueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  def queries_for(path, params)
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path, params: params }
    assert_response :success
    count
  end

  test "the number of queries does not grow with the categories or the buckets" do
    manager = dashboard_staff("Mona Manager", "manager")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    make = lambda do |category|
      Forefront::Ticket.create!(title: "T", description: "D", customer: customer, created_by: manager, assigned_to: manager,
                                category: category, priority: "medium", status: "open", created_at: 3.days.ago)
    end
    make.call("demo")
    sign_in_as(manager)
    few = queries_for("/forefront/reports/tickets", { breakdown: "day", period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    %w[tech issue request complaint proposal].each { |category| make.call(category) }
    many = queries_for("/forefront/reports/tickets", { breakdown: "day", period: "custom", from: 30.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    assert_operator (many - few).abs, :<=, 2
  end
end
