require "test_helper"

class Forefront::Reports::LeadSourceTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  # Records here are made days or hours ago and read under the default "This month",
  # so pin the clock mid-month; on the 1st–3rd they would fall into last month.
  setup do
    travel_to Time.zone.local(2026, 10, 20, 12)
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @web = forefront_source("Website")
    @ads = forefront_source("Ads")
  end

  def lead(source, created_at:, won: false, amount: 1_000)
    Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: source,
                            created_at: created_at, status: won ? "won" : "open", actual_amount: (amount if won))
  end

  def report_rows
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
  end

  test "leads created in the period by source, with wins, rate, revenue and days to win" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      lead(@web, created_at: 10.days.ago, won: true, amount: 4_000)
      lead(@web, created_at: 5.days.ago)
      lead(@ads, created_at: 2.days.ago)
      lead(@web, created_at: 60.days.ago)
      sign_in_as(@manager)

      get "/forefront/reports/lead_source"

      rows = report_rows.to_h { |row| [ row[0], row[2..] ] }
      assert_equal [ "2", "1", "50%", "₹4,000.00", "10.0" ], rows["Website"]
      assert_equal [ "1", "0", "0%", "₹0.00", "—" ], rows["Ads"]
    end
  end

  test "a won lead without won_at still counts as won but is left out of the days to win" do
    lead(@web, created_at: 10.days.ago, won: true, amount: 4_000)
    lead(@web, created_at: 5.days.ago, won: true, amount: 1_000).update_column(:won_at, nil)
    sign_in_as(@manager)

    get "/forefront/reports/lead_source"

    assert_response :success
    assert_equal [ "2", "2", "100%", "₹5,000.00", "10.0" ], report_rows.to_h { |row| [ row[0], row[2..] ] }["Website"]
  end

  test "breakdown by week adds a column per week and a total that adds up" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      lead(@web, created_at: Time.zone.local(2026, 10, 2, 9))
      lead(@web, created_at: Time.zone.local(2026, 10, 9, 9))
      sign_in_as(@manager)

      get "/forefront/reports/lead_source", params: { breakdown: "week" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      assert_includes headers, "Leads · Total"
      assert_includes headers, "Leads · 1 Oct – 4 Oct"
      website = report_rows.find { |row| row[0] == "Website" }
      week_cells = headers.each_index.select { |index| headers[index].start_with?("Leads · ") && headers[index] != "Leads · Total" }
      assert_equal 2, week_cells.sum { |index| website[index].to_i }
      assert_equal "2", website[headers.index("Leads · Total")]
    end
  end

  test "junk or unknown source and campaign filters are ignored" do
    lead(@web, created_at: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lead_source", params: { source_id: 999_999, campaign_id: "x" }
    assert_response :success
    get "/forefront/reports/lead_source", params: { "source_id" => [ @web.id ] }
    assert_response :success
    assert report_rows.any? { |row| row[0] == "Website" }
  end

  test "a sales person can't open a Manager-only report or its CSV, and nothing is audited" do
    sign_in_as(@ravi)

    get "/forefront/reports/lead_source"
    assert_redirected_to "/forefront/"
    get "/forefront/reports/lead_source.csv"
    assert_response :redirect
    assert_equal 0, Forefront::AuditEvent.where(action: "exported_report").count
  end

  test "the CSV of a broken-down report matches its table" do
    lead(@web, created_at: 1.day.ago, won: true, amount: 2_500)
    sign_in_as(@manager)

    get "/forefront/reports/lead_source.csv", params: { breakdown: "month" }

    csv = CSV.parse(response.body)
    assert_equal "Source", csv.first.first
    assert csv.any? { |row| row.first == "Website" && row.include?("2500.00") }
  end
end

class Forefront::Reports::LeadSourceQueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  def queries_for(path, params)
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path, params: params }
    assert_response :success
    count
  end

  test "the number of queries does not grow with the rows or the buckets" do
    manager = dashboard_staff("Mona Manager", "manager")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    make = lambda do |name|
      Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: manager, assigned_to: manager,
                              source: forefront_source(name), created_at: 3.days.ago)
    end
    make.call("S1")
    sign_in_as(manager)
    few = queries_for("/forefront/reports/lead_source", { breakdown: "day", period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    5.times { |i| make.call("Extra #{i}") }
    many = queries_for("/forefront/reports/lead_source", { breakdown: "day", period: "custom", from: 30.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    assert_operator (many - few).abs, :<=, 2
  end
end
