require "test_helper"

# A Deadline (CONTEXT.md): the due date by which a Lead is won or lost, or a
# Ticket resolved, required and never further ahead than the Admin-set
# limit. Once it has passed the assignee may only look; a Manager or Admin
# extends it with a note.
class Forefront::DeadlinesTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @today = Date.new(2026, 10, 6)
    travel_to @today.in_time_zone(Time.zone).change(hour: 10)
  end

  def lead_params(**overrides)
    { title: "Big Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: @product.id }.merge(overrides)
  end

  def ticket_params(**overrides)
    { title: "Call Acme", description: "D", customer_id: @customer.id, category: "enquiry", priority: "medium", product_id: @product.id, source_id: forefront_source.id }.merge(overrides)
  end

  def lead(due_at: @today + 10, **attrs)
    Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: "contacted", due_at: due_at, **attrs)
  end

  test "the limits are admin settings, 30 days for a lead and 7 for a ticket" do
    sign_in_as(@admin)
    get "/forefront/settings"

    assert_select "input[name='settings[lead_close_within_days]'][value='30']"
    assert_select "input[name='settings[ticket_close_within_days]'][value='7']"
  end

  test "a new lead needs a deadline, prefilled with the limit, and refuses a later one" do
    sign_in_as(@rep)
    get "/forefront/leads/new"
    assert_select "input[name='lead[due_at]'][required][value='2026-11-05'][max='2026-11-05']"

    post "/forefront/leads", params: { lead: lead_params(due_at: ""), first_step: forefront_first_step }
    assert_response :unprocessable_entity
    assert_match "Due at can&#39;t be blank", response.body

    post "/forefront/leads", params: { lead: lead_params(due_at: "2026-11-06"), first_step: forefront_first_step }
    assert_response :unprocessable_entity
    assert_match "Due at can&#39;t be more than 30 days ahead", response.body

    post "/forefront/leads", params: { lead: lead_params(due_at: "2026-11-05"), first_step: forefront_first_step }
    assert_equal Date.new(2026, 11, 5), Forefront::Lead.find_by!(title: "Big Deal").due_at
  end

  test "a new ticket needs a deadline within the ticket limit" do
    sign_in_as(@rep)
    get "/forefront/tickets/new"
    assert_select "input[name='ticket[due_at]'][required][value='2026-10-13'][max='2026-10-13']"

    post "/forefront/tickets", params: { ticket: ticket_params(due_at: "2026-10-14") }
    assert_response :unprocessable_entity
    assert_match "Due at can&#39;t be more than 7 days ahead", response.body
    assert_nil Forefront::Ticket.find_by(title: "Call Acme")
  end

  test "a stage ticket's due date is capped by the ticket limit" do
    record = lead
    sign_in_as(@rep)

    post "/forefront/leads/#{record.id}/status_histories", params: { status_history: { status: "demo", ticket_due_at: "2026-11-01" } }

    assert_equal @today + 7, record.tickets.sole.due_at
  end

  test "once the deadline has passed the assignee can only look, and the page says so" do
    late = lead(due_at: @today - 1)
    sign_in_as(@rep)
    get "/forefront/leads/#{late.id}"
    assert_match "Deadline passed", response.body
    assert_select "button", text: "Change Stage", count: 0

    post "/forefront/leads/#{late.id}/status_histories", params: { status_history: { status: "demo" } }
    assert late.reload.contacted?
    post "/forefront/leads/#{late.id}/activities", params: { activity: { activity_type: "comment", body: "Still trying" } }
    assert_equal 0, late.activities.count
    post "/forefront/leads/#{late.id}/followups", params: { followup: { followup_type: "call", scheduled_for: "2026-10-07T10:00" } }
    assert_equal 0, late.followups.count
  end

  test "a manager extends a passed deadline with a note, within the limit, and the assignee works again" do
    late = lead(due_at: @today - 1)
    sign_in_as(@manager)
    get "/forefront/leads/#{late.id}"
    assert_select "button", text: "Extend deadline"

    post "/forefront/leads/#{late.id}/deadline", params: { deadline: { due_at: "2026-11-06", note: "Budget approval slipped" } }
    assert late.reload.overdue?

    post "/forefront/leads/#{late.id}/deadline", params: { deadline: { due_at: "2026-10-20", note: "" } }
    assert late.reload.overdue?

    post "/forefront/leads/#{late.id}/deadline", params: { deadline: { due_at: "2026-10-20", note: "Budget approval slipped" } }
    assert_redirected_to "/forefront/leads/#{late.id}"
    assert_equal Date.new(2026, 10, 20), late.reload.due_at
    event = Forefront::AuditEvent.find_by!(actor: @manager, action: "extended_deadline", auditable: late)
    assert_equal "Budget approval slipped", event.audited_changes["note"].last

    sign_in_as(@rep)
    post "/forefront/leads/#{late.id}/activities", params: { activity: { activity_type: "comment", body: "Back on it" } }
    assert_equal 1, late.activities.count
  end

  test "the assignee can't extend, and a manager can't push a ticket past the ticket limit" do
    late = lead(due_at: @today - 1)
    sign_in_as(@rep)
    post "/forefront/leads/#{late.id}/deadline", params: { deadline: { due_at: "2026-10-20", note: "Please" } }
    assert_equal @today - 1, late.reload.due_at

    ticket = Forefront::Ticket.create!(title: "Call", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: @today - 2)
    sign_in_as(@manager)
    post "/forefront/tickets/#{ticket.id}/deadline", params: { deadline: { due_at: "2026-10-14", note: "Customer travelling" } }
    assert_equal @today - 2, ticket.reload.due_at
    post "/forefront/tickets/#{ticket.id}/deadline", params: { deadline: { due_at: "2026-10-13", note: "Customer travelling" } }
    assert_equal Date.new(2026, 10, 13), ticket.reload.due_at
  end
end
