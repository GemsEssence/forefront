require "test_helper"

class Forefront::Reports::LeadStageTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(owner, status, amount, entered_stage: nil)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                   source: forefront_source, status: status, estimated_amount: amount, created_at: 20.days.ago)
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Open", new_status: Forefront::Lead.statuses.fetch(status), changed_by: owner, created_at: entered_stage) if entered_stage
    lead
  end

  def report_rows
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
  end

  test "open leads per stage with expected value and days in the current stage" do
    lead(@ravi, "demo", 1_000, entered_stage: 4.days.ago)
    lead(@ravi, "demo", 3_000, entered_stage: 2.days.ago)
    lead(@ravi, "open", 500)
    lead(@otto, "demo", 9_999, entered_stage: 1.day.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lead_stage"

    assert_response :success
    rows = report_rows.to_h { |row| [ row[0], row[1..] ] }
    assert_equal [ "2", "₹4,000.00", "3.0" ], rows["Demo"]
    assert_equal [ "1", "₹500.00", "20.0" ], rows["Open"]
  end

  test "exports the same table as CSV and records the export" do
    lead(@ravi, "demo", 1_000, entered_stage: 4.days.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lead_stage.csv"

    assert_response :success
    csv = CSV.parse(response.body)
    assert_equal [ "Stage", "Open leads", "Expected value", "Avg days in stage" ], csv.first
    assert_includes csv, [ "Demo", "1", "1000.00", "4.0" ]
    assert_equal %w[report filters], Forefront::AuditEvent.where(action: "exported_report").last.audited_changes.keys
    event = Forefront::AuditEvent.where(action: "exported_report").last
    assert_equal @manager.id, event.actor_id
    assert_equal "lead_stage", event.audited_changes["report"].last
  end

  test "the export records the filters it ran with" do
    web = forefront_source("Web")
    sign_in_as(@manager)

    get "/forefront/reports/lead_stage.csv", params: { source_id: web.id }

    event = Forefront::AuditEvent.where(action: "exported_report").last
    assert_equal web.id, JSON.parse(event.audited_changes["filters"].last)["source_id"]
  end

  test "source and campaign narrow the table, and an unknown id is ignored" do
    web = forefront_source("Web")
    expo = forefront_source("Expo")
    campaign = Forefront::Campaign.create!(name: "Spring", source: web, created_by: @manager, starts_on: 30.days.ago.to_date, ends_on: 1.day.from_now.to_date)
    lead(@ravi, "demo", 1_000)
    Forefront::Lead.create!(title: "W", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: web, campaign: campaign, status: "demo", estimated_amount: 200, created_at: 5.days.ago)
    Forefront::Lead.create!(title: "E", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: expo, status: "demo", estimated_amount: 30, created_at: 5.days.ago)
    sign_in_as(@manager)

    get "/forefront/reports/lead_stage"
    unfiltered = report_rows
    assert_equal [ "3", "₹1,230.00" ], unfiltered.find { |r| r[0] == "Demo" }[1..2]

    get "/forefront/reports/lead_stage", params: { source_id: web.id }
    assert_equal [ "1", "₹200.00" ], report_rows.find { |r| r[0] == "Demo" }[1..2]

    get "/forefront/reports/lead_stage", params: { campaign_id: campaign.id }
    assert_equal [ "1", "₹200.00" ], report_rows.find { |r| r[0] == "Demo" }[1..2]

    get "/forefront/reports/lead_stage", params: { source_id: 0, campaign_id: 999_999 }
    assert_response :success
    assert_equal unfiltered, report_rows
  end
end
