require "test_helper"

# Found driving the demo app through the life cycle (lifecycle-guidance issue 11).
class Forefront::WalkthroughFixesTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    travel_to Time.zone.local(2026, 10, 6, 9)
    sign_in_as(@rep)
  end

  test "winning or losing a lead cancels its pending followups, so they leave the worklist" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "negotiation", due_at: Date.current + 10)
    pending = lead.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 5, 10), assigned_to: @rep, created_by: @rep)

    post "/forefront/leads/#{lead.id}/stage_action", params: { stage_action: { kind: "won", actual_amount: "900" } }

    assert lead.reload.won?
    assert pending.reload.cancelled?
    get "/forefront/my_work"
    assert_select "[data-section='overdue'] li[data-row]", count: 0
  end

  test "resolving a ticket cancels its pending followups" do
    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5)
    pending = ticket.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 8, 10), assigned_to: @rep, created_by: @rep)

    post "/forefront/tickets/#{ticket.id}/status_histories", params: { status_history: { status: "resolved" } }

    assert ticket.reload.resolved?
    assert pending.reload.cancelled?
  end

  test "timeline entries recorded in the same second still read in the order they happened" do
    post "/forefront/leads", params: { lead: { title: "Big Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id,
                                               product_id: @product.id, due_at: (Date.current + 20).iso8601 },
                                       first_step: { followup_type: "call", scheduled_for: "2026-10-07T10:00" } }
    lead = Forefront::Lead.find_by!(title: "Big Deal")

    get "/forefront/leads/#{lead.id}"

    lines = css_select("[data-timeline] li[data-entry]").map { |li| li.text.squish }
    assert_match(/Scheduled a call/, lines[0])
    assert_match(/Assigned to Ravi Rep/, lines[1])
    assert_match(/Created/, lines[2])
  end

  test "the lead and ticket pages don't repeat the deadline as a Due Date row" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "open", due_at: Date.current + 10)
    get "/forefront/leads/#{lead.id}"
    assert_select "dt", text: "Due Date", count: 0
    assert_select "[data-deadline]", text: /Deadline/

    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5)
    get "/forefront/tickets/#{ticket.id}"
    assert_select "dt", text: "Due Date", count: 0
  end
end
