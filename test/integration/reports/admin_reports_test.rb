require "test_helper"

class Forefront::Reports::AdminReportsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def rows
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
  end

  test "the audit report lists reveals, exports and settings changes in the period, admins only" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      Forefront::AuditEvent.record!(actor: @manager, action: "revealed_contact", auditable: @customer, audited_changes: {})
      Forefront::AuditEvent.record!(actor: @manager, action: "added_activity", auditable: @customer, audited_changes: {})
      sign_in_as(@admin)
      get "/forefront/reports/lead_stage.csv"

      get "/forefront/reports/audit"

      actions = rows.map { |row| row[2] }
      assert_includes actions, "Revealed contact"
      assert_includes actions, "Exported report"
      assert_not_includes actions, "Added activity"

      reveal = rows.find { |row| row[2] == "Revealed contact" }
      assert_equal [ "20 Oct 2026 12:00", "Mona Manager", "Revealed contact", "Acme", "" ], reveal
      export = rows.find { |row| row[2] == "Exported report" }
      assert_equal "Asha Admin", export[1]
      assert_equal "—", export[3]
      assert_includes export[4], "Report: — → lead_stage"

      sign_in_as(@manager)
      get "/forefront/reports/audit"
      assert_redirected_to "/forefront/"
    end
  end

  test "the audit report shows settings changes and leaves out events before the period" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      Forefront::AuditEvent.record!(actor: @admin, action: "updated_settings", auditable: nil,
                                    audited_changes: { "currency" => [ "INR", "USD" ] })
      before = Forefront::AuditEvent.record!(actor: @manager, action: "revealed_contact", auditable: @customer, audited_changes: {})
      Forefront::AuditEvent.where(id: before.id).update_all(created_at: Time.zone.local(2026, 9, 30, 23, 59, 59))
      sign_in_as(@admin)

      get "/forefront/reports/audit"

      assert_equal [ [ "20 Oct 2026 12:00", "Asha Admin", "Updated settings", "—", "Currency: INR → USD" ] ], rows
    end
  end

  test "data quality counts each check" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      product = Forefront::Product.create!(name: "Widget")
      Forefront::Customer.create!(name: "No email", phone: "555-0199")
      Forefront::Customer.create!(name: "Has email", phone: "555-0198", email: "has@example.com")
      lead = lambda do |title, **attrs|
        Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @manager,
                                assigned_to: @manager, source: forefront_source, **attrs)
      end
      lead.call("Orphan, no product")
      followed = lead.call("Followed up", product: product)
      Forefront::Followup.create!(followupable: followed, assigned_to: @manager, created_by: @manager, followup_type: "call",
                                  status: "pending", scheduled_for: 1.day.from_now)
      lead.call("Won, unpaid", product: product, status: "won", actual_amount: 100)
      paid = lead.call("Won, paid", product: product, status: "won", actual_amount: 100)
      Forefront::Payment.create!(lead: paid, total_amount: 100)
      [ Time.zone.local(2026, 10, 5, 9), Time.zone.local(2026, 9, 30, 23, 59, 59) ].each do |at|
        event = Forefront::AuditEvent.record!(actor: @admin, action: "rejected_signup", auditable: product,
                                              audited_changes: { "errors" => [ nil, "Phone can't be blank" ] })
        Forefront::AuditEvent.where(id: event.id).update_all(created_at: at)
      end
      sign_in_as(@admin)

      get "/forefront/reports/data_quality"

      assert_equal [
        [ "Open leads with no followup", "1" ],
        [ "Rejected Signup API calls", "1" ],
        [ "Customers with no email", "2" ],
        [ "Leads with no product", "1" ],
        [ "Won leads with no payment", "1" ]
      ], rows

      sign_in_as(@manager)
      get "/forefront/reports/data_quality"
      assert_redirected_to "/forefront/"
    end
  end
end
