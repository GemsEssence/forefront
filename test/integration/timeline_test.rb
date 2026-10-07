require "test_helper"

# Every record's page carries its own Timeline (CONTEXT.md: Audit event):
# what happened to this one Ticket or Lead, newest first, for anyone who
# may open it. Managers and Admins can jump to the Audit log for it.
class Forefront::TimelineTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @colleague = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: [ @rep, @colleague ])
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    travel_to Time.zone.local(2026, 10, 6, 9)
    sign_in_as(@rep)
  end

  def entries
    css_select("[data-timeline] li[data-entry]").map { |li| li.text.squish }
  end

  test "a lead's life shows on its page, newest first, to the sales person working it" do
    post "/forefront/leads", params: { lead: { title: "Big Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id,
                                               product_id: @product.id, due_at: (Date.current + 20).iso8601 },
                                       first_step: { followup_type: "call", scheduled_for: "2026-10-07T10:00" } }
    lead = Forefront::Lead.find_by!(title: "Big Deal")
    travel 1.hour
    post "/forefront/leads/#{lead.id}/activities", params: { activity: { activity_type: "comment", body: "Spoke to the CTO" } }
    travel 1.hour
    post "/forefront/leads/#{lead.id}/stage_action", params: { stage_action: { kind: "contacted", followup_type: "demo", scheduled_for: "2026-10-09T11:00", note: "Keen" } }
    travel 1.hour
    post "/forefront/followups/#{lead.followups.order(:scheduled_for).first.id}/completion",
         params: { completion: { outcome: "They want pricing", next: "stage", kind: "proposal", ticket_due_at: (Date.current + 3).iso8601 } }
    travel 1.hour
    sign_in_as(@manager)
    post "/forefront/leads/#{lead.id}/deadline", params: { deadline: { due_at: (Date.current + 25).iso8601, note: "Board meets late" } }
    travel 1.minute
    post "/forefront/leads/#{lead.id}/assignments", params: { assignment: { to_user_id: @colleague.id, note: "Meera knows them" } }

    sign_in_as(@colleague)
    get "/forefront/leads/#{lead.id}"
    assert_response :success

    lines = entries
    assert_match(/Mona Manager .*Assigned to Meera Rep \(from Ravi Rep\).*Meera knows them/, lines[0])
    assert_match(/Mona Manager .*Deadline moved .*Board meets late/, lines[1])
    assert_match(/Ravi Rep .*Proposal.*ticket/i, lines.join(" | "))
    assert_match(/Ravi Rep .*Contacted → Proposal/, lines.join(" | "))
    assert_match(/Ravi Rep .*Completed .*call.*They want pricing/, lines.join(" | "))
    assert_match(/Ravi Rep .*Scheduled .*demo .*9 Oct 11:00/, lines.join(" | "))
    assert_match(/Ravi Rep .*Open → Contacted.*Keen/, lines.join(" | "))
    assert_match(/Ravi Rep .*Spoke to the CTO/, lines.join(" | "))
    assert_match(/Ravi Rep .*Created/, lines.last)
    assert_select "a[href*='/forefront/audit_log']", count: 0
  end

  test "a ticket's timeline shows its status changes and notes, and money shows on a won lead" do
    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5)
    post "/forefront/tickets/#{ticket.id}/status_histories", params: { status_history: { status: "in_progress", note: "On it" } }
    post "/forefront/tickets/#{ticket.id}/activities", params: { activity: { activity_type: "internal_note", body: "Check the 20-seat tier" } }
    get "/forefront/tickets/#{ticket.id}"
    assert_match(/Check the 20-seat tier/, entries.first)
    assert_match(/Open → In Progress.*On it/, entries.second)

    lead = Forefront::Lead.create!(title: "Won Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "won", actual_amount: 1000, due_at: Date.current + 5)
    post "/forefront/leads/#{lead.id}/payment", params: { payment: { total_amount: "1000" } }
    travel 1.minute
    post "/forefront/leads/#{lead.id}/payment/receipts", params: { receipt: { amount: "400", received_on: "2026-10-06", payment_method: "upi", reference: "UPI-1" } }
    get "/forefront/leads/#{lead.id}"
    assert_match(/Received .*400/, entries.first)
    assert_match(/Recorded payment .*1,000/, entries.second)
  end

  test "a manager's Audit trail link opens the audit log filtered to that one record" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "contacted", due_at: Date.current + 5)
    other = Forefront::Lead.create!(title: "Other Deal", description: "D", customer: Forefront::Customer.create!(name: "Globex", phone: "555-0199"),
                                    created_by: @rep, assigned_to: @rep, source: forefront_source, product: @product, status: "contacted", due_at: Date.current + 5)
    post "/forefront/leads/#{lead.id}/activities", params: { activity: { activity_type: "comment", body: "Big note" } }
    post "/forefront/leads/#{other.id}/activities", params: { activity: { activity_type: "comment", body: "Other note" } }

    sign_in_as(@manager)
    get "/forefront/leads/#{lead.id}"
    assert_select "a[href='/forefront/audit_log?auditable_id=#{lead.id}&auditable_type=Forefront%3A%3ALead']", text: "Audit trail"

    get "/forefront/audit_log", params: { auditable_type: "Forefront::Lead", auditable_id: lead.id }
    assert_match "Big note", response.body
    assert_no_match "Other note", response.body
  end
end
