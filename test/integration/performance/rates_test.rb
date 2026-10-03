require "test_helper"

class Forefront::Performance::RatesTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def enquiry(title, category: "enquiry")
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                              category: category, priority: "medium", status: "open")
  end

  def finish(ticket, status = "resolved")
    ticket.update!(status: status)
    Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: Forefront::Ticket.statuses.fetch(status), changed_by: @ravi)
  end

  test "tickets converted out of enquiry and signup tickets finished or converted in the period" do
    converted = enquiry("Converted")
    Forefront::AuditEvent.record!(actor: @ravi, action: "converted", auditable: converted, audited_changes: {})
    finish(converted)
    finish(enquiry("Just resolved", category: "signup"), "closed")
    enquiry("Still open")
    finish(Forefront::Ticket.create!(title: "Not an enquiry", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                     category: "request", priority: "medium", status: "open"))
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "ticket_to_lead")
    assert_equal [ "Converted" ], drill(:enquiries_converted, member_id: @ravi.id).map { |row| row.split(" Acme").first }
    assert_equal [ "Converted", "Just resolved" ], drill(:enquiries_handled, member_id: @ravi.id).map { |row| row.split(" Acme").first }.sort
  end

  test "won out of won plus lost, for leads closed in the period" do
    Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                            status: "won", actual_amount: 100)
    lost = Forefront::Lead.create!(title: "Lost", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                                   status: "lost", lost_reason: Forefront::LostReason.create!(name: "Price"), lost_note: "Too dear")
    Forefront::StatusHistory.create!(trackable: lost, old_status: "Demo", new_status: "Lost", changed_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "lead_to_win")
    assert_equal 2, drill(:leads_closed, member_id: @ravi.id).size
  end

  test "nothing closed shows a dash" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "—", cell("Ravi Rep", "lead_to_win")
  end
end
