require "test_helper"

# Completing a Followup (CONTEXT.md: Followup) records the outcome and then
# chooses what comes next: another Followup, a stage action or status, or
# closing the record. It is never completed into nothing.
class Forefront::FollowupCompletionTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @price = Forefront::LostReason.find_or_create_by!(name: "Price")
    travel_to Time.zone.local(2026, 10, 6, 9)
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                    product: @product, status: "contacted", due_at: Date.current + 20)
    @followup = @lead.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 6, 10), assigned_to: @rep, created_by: @rep)
    sign_in_as(@rep)
  end

  def complete(followup = @followup, **fields)
    post "/forefront/followups/#{followup.id}/completion", params: { completion: fields },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }
  end

  test "Done records the outcome and schedules the next followup" do
    get "/forefront/leads/#{@lead.id}"
    assert_select "#followup_#{@followup.id} button", text: "Done"

    complete(outcome: "Priya wants a demo next week", next: "followup", followup_type: "demo", scheduled_for: "2026-10-13T11:00")

    assert_redirected_to "/forefront/leads/#{@lead.id}"
    @followup.reload
    assert @followup.completed?
    assert_equal [ "Priya wants a demo next week", Time.zone.local(2026, 10, 6, 9) ], [ @followup.outcome, @followup.completed_at ]
    nxt = @lead.followups.pending.sole
    assert_equal [ "demo", Time.zone.local(2026, 10, 13, 11), @rep ], [ nxt.followup_type, nxt.scheduled_for, nxt.assigned_to ]
    event = Forefront::AuditEvent.find_by!(actor: @rep, action: "completed_followup", auditable: @lead)
    assert_equal "Priya wants a demo next week", event.audited_changes["outcome"].last
  end

  test "Done can move the lead on with a stage action, or lose it" do
    complete(outcome: "Agreed to a demo", next: "stage", kind: "demo", ticket_due_at: "2026-10-09")

    @lead.reload
    assert @lead.demo?
    assert @followup.reload.completed?
    assert_equal Date.new(2026, 10, 9), @lead.tickets.new_app_demo.sole.due_at

    second = @lead.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 8, 10), assigned_to: @rep, created_by: @rep)
    complete(second, outcome: "Chose a competitor", next: "stage", kind: "lost", lost_reason_id: @price.id, note: "Cheaper elsewhere")

    assert @lead.reload.lost?
    assert second.reload.completed?
  end

  test "Done needs an outcome and a next step" do
    complete(outcome: "", next: "followup", followup_type: "call", scheduled_for: "2026-10-13T11:00")
    assert @followup.reload.pending?
    assert_match "Outcome can't be blank", flash[:alert]

    complete(outcome: "Spoke", next: "")
    assert @followup.reload.pending?
    assert_match "Say what happens next", flash[:alert]

    complete(outcome: "Spoke", next: "followup", followup_type: "call", scheduled_for: "")
    assert @followup.reload.pending?
    assert_match "Scheduled for can't be blank", flash[:alert]
  end

  test "on a ticket, Done can resolve it or change its status, which leaves its due date as the next step" do
    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5)
    first = ticket.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 6, 10), assigned_to: @rep, created_by: @rep)
    complete(first, outcome: "Left a message", next: "status", status: "waiting_customer")
    assert first.reload.completed?
    assert ticket.reload.waiting_customer?
    assert_not ticket.needs_next_step?

    second = ticket.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 7, 10), assigned_to: @rep, created_by: @rep)
    complete(second, outcome: "Answered their question", next: "close")
    assert ticket.reload.resolved?
    assert second.reload.completed?
  end

  test "cancelling the only followup from the edit dialog is refused; cancelling one of two is fine" do
    patch "/forefront/leads/#{@lead.id}/followups/#{@followup.id}", params: { followup: { status: "cancelled" } },
          headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }
    assert @followup.reload.pending?
    assert_match "would leave Big Deal without a next step", flash[:alert]

    @lead.followups.create!(followup_type: "email", scheduled_for: Time.zone.local(2026, 10, 8, 10), assigned_to: @rep, created_by: @rep)
    patch "/forefront/leads/#{@lead.id}/followups/#{@followup.id}", params: { followup: { status: "cancelled" } }
    assert @followup.reload.cancelled?
  end

  test "only the assignee gets Done" do
    sign_in_as(@manager)
    get "/forefront/leads/#{@lead.id}"
    assert_select "#followup_#{@followup.id} button", text: "Done", count: 0

    complete(outcome: "Did it", next: "followup", followup_type: "call", scheduled_for: "2026-10-13T11:00")
    assert @followup.reload.pending?
  end
end
