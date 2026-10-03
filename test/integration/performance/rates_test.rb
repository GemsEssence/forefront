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

  def convert(ticket, at: Time.current)
    Forefront::AuditEvent.record!(actor: @ravi, action: "converted", auditable: ticket, audited_changes: {})
    Forefront::AuditEvent.where(auditable: ticket, action: "converted").update_all(created_at: at)
  end

  def long_ago
    3.months.ago
  end

  def new_lead(title, **attrs)
    Forefront::Lead.create!({ title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source }.merge(attrs))
  end

  def lose(title, reason, at: Time.current)
    lead = new_lead(title, status: "lost", lost_reason: reason, lost_note: "Note")
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Demo", new_status: "Lost", changed_by: @ravi, created_at: at)
    lead
  end

  test "ticket rate ignores conversions and finishes outside the period" do
    inside = enquiry("Inside")
    Forefront::AuditEvent.record!(actor: @ravi, action: "converted", auditable: inside, audited_changes: {})
    old_conversion = enquiry("Old conversion")
    convert(old_conversion, at: long_ago)
    old_resolved = enquiry("Old resolved")
    finish(old_resolved)
    Forefront::StatusHistory.where(trackable: old_resolved).update_all(created_at: long_ago)
    converted_then_resolved = enquiry("Converted before, resolved now")
    convert(converted_then_resolved, at: long_ago)
    finish(converted_then_resolved)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 1 (100%)", cell("Ravi Rep", "ticket_to_lead")
    assert_equal [ "Inside" ], drill(:enquiries_converted, member_id: @ravi.id).map { |row| row.split(" Acme").first }
    assert_equal [ "Inside" ], drill(:enquiries_handled, member_id: @ravi.id).map { |row| row.split(" Acme").first }
  end

  test "lead rate ignores leads won or lost outside the period" do
    new_lead("Won now", status: "won", actual_amount: 100)
    new_lead("Won before", status: "won", actual_amount: 100).update_columns(won_at: long_ago)
    lose("Lost now", Forefront::LostReason.create!(name: "Price"))
    lose("Lost before", Forefront::LostReason.create!(name: "Timing"), at: long_ago)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "lead_to_win")
    assert_equal 2, drill(:leads_closed, member_id: @ravi.id).size
  end

  test "leads lost lists those lost in the period, and narrows to a reason" do
    price = Forefront::LostReason.create!(name: "Price")
    timing = Forefront::LostReason.create!(name: "Timing")
    lose("Lost on price", price)
    lose("Lost on timing", timing)
    lose("Lost long ago", price, at: long_ago)
    sign_in_as(@manager)

    assert_equal [ "Lost on price", "Lost on timing" ], drill(:leads_lost, member_id: @ravi.id).map { |row| row.split(" Acme").first }.sort
    assert_equal [ "Lost on price" ], drill(:leads_lost, member_id: @ravi.id, slice: price.id).map { |row| row.split(" Acme").first }
  end

  test "nothing closed shows a dash" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "—", cell("Ravi Rep", "lead_to_win")
  end
end
