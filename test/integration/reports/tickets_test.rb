require "test_helper"

class Forefront::Reports::TicketsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  # Records here are made days or hours ago and read under the default "This month",
  # so pin the clock mid-month; on the 1st–3rd they would fall into last month.
  setup do
    travel_to Time.zone.local(2026, 10, 20, 12)
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def ticket(category, created_at:, resolved_after: nil, lead: nil, by: @ravi, campaign: nil)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: by, assigned_to: by,
                                       category: category, priority: "medium", status: "open", created_at: created_at, lead: lead, campaign: campaign)
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

  test "the campaign filter keeps only that campaign's tickets in every column" do
    source = forefront_source("Website")
    spring = Forefront::Campaign.create!(name: "Spring", source: source, created_by: @manager, starts_on: 30.days.ago.to_date, ends_on: 1.day.from_now.to_date)
    summer = Forefront::Campaign.create!(name: "Summer", source: source, created_by: @manager, starts_on: 30.days.ago.to_date, ends_on: 1.day.from_now.to_date)
    lead_a = Forefront::Lead.create!(title: "A", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: source)
    lead_b = Forefront::Lead.create!(title: "B", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: source)
    ticket("demo", created_at: 3.days.ago, resolved_after: 2.hours, lead: lead_a, campaign: spring)
    ticket("demo", created_at: 2.days.ago, resolved_after: 4.hours, lead: lead_a, campaign: spring)
    ticket("demo", created_at: 2.days.ago, resolved_after: 10.hours, lead: lead_b, campaign: summer)
    ticket("tech", created_at: 1.day.ago, campaign: summer)
    ticket("request", created_at: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/tickets", params: { campaign_id: spring.id }

    assert_equal [ "Demo" ], report_rows.keys
    assert_equal [ "2", "2", "3.0", "2.0" ], report_rows["Demo"]
  end

  test "a custom period includes its first second and excludes the second before it, for opened and resolved" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      ticket("demo", created_at: Time.zone.local(2026, 9, 30, 23, 59, 59))
      ticket("tech", created_at: Time.zone.local(2026, 10, 1, 0, 0, 0))
      ticket("issue", created_at: Time.zone.local(2026, 9, 29, 23, 59, 59), resolved_after: 1.second)
      ticket("request", created_at: Time.zone.local(2026, 9, 30, 12), resolved_after: 12.hours)
      sign_in_as(@manager)

      get "/forefront/reports/tickets", params: { period: "custom", from: "2026-10-01", to: "2026-10-31" }

      assert_equal %w[Request Tech], report_rows.keys.sort
      assert_equal [ "0", "1", "12.0", "—" ], report_rows["Request"]
      assert_equal [ "1", "0", "—", "—" ], report_rows["Tech"]
    end
  end

  test "week breakdown puts resolutions and their hours in the right week, with the Sunday 23:59 and Monday 00:00 edge" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ticket("demo", created_at: Time.zone.local(2026, 10, 4, 21, 59), resolved_after: 2.hours)
      ticket("demo", created_at: Time.zone.local(2026, 10, 4, 21, 0), resolved_after: 3.hours)
      sign_in_as(@manager)

      get "/forefront/reports/tickets", params: { breakdown: "week" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      demo = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }.find { |row| row[0] == "Demo" }
      cell = ->(title, week) { demo[headers.index("#{title} · #{week}")] }
      assert_equal "2", cell.call("Opened", "28 Sep – 4 Oct")
      assert_equal "1", cell.call("Resolved or closed", "28 Sep – 4 Oct")
      assert_equal "2.0", cell.call("Avg hours to resolve", "28 Sep – 4 Oct")
      assert_equal "0", cell.call("Opened", "5 Oct – 11 Oct")
      assert_equal "1", cell.call("Resolved or closed", "5 Oct – 11 Oct")
      assert_equal "3.0", cell.call("Avg hours to resolve", "5 Oct – 11 Oct")
      assert_equal "2", cell.call("Resolved or closed", "Total")
    end
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
