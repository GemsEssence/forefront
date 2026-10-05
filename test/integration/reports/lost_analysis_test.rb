# test/integration/reports/lost_analysis_test.rb
require "test_helper"

class Forefront::Reports::LostAnalysisTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  # Records here are made days or hours ago and read under the default "This month",
  # so pin the clock mid-month; on the 1st–3rd they would fall into last month.
  setup do
    travel_to Time.zone.local(2026, 10, 20, 12)
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @price = Forefront::LostReason.create!(name: "Price")
    @timing = Forefront::LostReason.create!(name: "Timing")
  end

  def lose(owner, reason, from:, amount:, source: forefront_source, at: 1.day.ago)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: owner, assigned_to: owner, source: source,
                                   status: "lost", lost_reason: reason, lost_note: "N", estimated_amount: amount)
    Forefront::StatusHistory.create!(trackable: lead, old_status: Forefront::Lead.statuses.fetch(from), new_status: "Lost", changed_by: owner, created_at: at)
  end

  test "lost leads per reason with value, usual stage at loss, top person and top source" do
    lose(@ravi, @price, from: "proposal", amount: 1_000)
    lose(@ravi, @price, from: "proposal", amount: 2_000, source: forefront_source("Ads"))
    lose(@sara, @price, from: "demo", amount: 500)
    lose(@sara, @timing, from: "demo", amount: 700)
    lose(@sara, @timing, from: "demo", amount: 9_999, at: 3.months.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    rows = report_rows
    assert_equal [ "3", "₹3,500.00", "Proposal", "Ravi Rep", "Website" ], rows["Price"]
    assert_equal [ "1", "₹700.00", "Demo", "Sara Seller", "Website" ], rows["Timing"]
  end

  test "a lead lost twice in the period is counted once, at the stage of its latest loss" do
    lead = lose(@ravi, @price, from: "demo", amount: 100, at: 3.days.ago)
    Forefront::StatusHistory.create!(trackable: lead.trackable, old_status: Forefront::Lead.statuses.fetch("negotiation"), new_status: "Lost", changed_by: @ravi, created_at: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    assert_equal [ "1", "₹100.00", "Negotiation", "Ravi Rep", "Website" ], report_rows["Price"]
  end

  test "a lost lead without a reason is listed under No reason" do
    lead = lose(@ravi, @price, from: "demo", amount: 100)
    lead.trackable.update_columns(lost_reason_id: nil)
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    assert_equal [ "1", "₹100.00", "Demo", "Ravi Rep", "Website" ], report_rows["No reason"]
  end

  test "a manager only sees losses within their team" do
    outsider = dashboard_staff("Olga Outsider", "sales_person", manager: dashboard_staff("Other Manager", "manager"))
    lose(@ravi, @price, from: "demo", amount: 100)
    lose(outsider, @timing, from: "demo", amount: 900)
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    assert_equal [ "Price" ], report_rows.keys
  end

  test "a lead lost and then reopened is not counted" do
    lead = lose(@ravi, @price, from: "demo", amount: 100)
    lose(@ravi, @timing, from: "demo", amount: 50)
    lead.trackable.update!(status: "demo")
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    assert_equal [ "Timing" ], report_rows.keys
  end

  test "No reason is always the last row, even with the most leads" do
    lose(@ravi, @price, from: "demo", amount: 100)
    2.times { lose(@ravi, @price, from: "demo", amount: 1).trackable.update_columns(lost_reason_id: nil) }
    sign_in_as(@manager)

    get "/forefront/reports/lost_analysis"

    assert_equal [ "Price", "No reason" ], report_rows.keys
    assert_equal "2", report_rows["No reason"].first
  end

  private

  def report_rows
    css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
  end
end
