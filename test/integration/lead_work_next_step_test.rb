require "test_helper"

class Forefront::LeadWorkNextStepTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "contacted")
    sign_in_as(@rep)
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "demo" } }
    @demo_ticket = @lead.tickets.demo.sole
  end

  def resolve_demo(**next_step)
    post "/forefront/tickets/#{@demo_ticket.id}/status_histories",
         params: { status_history: { status: "resolved", note: "Demo went well", **next_step } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@demo_ticket.id}" }
  end

  test "resolving the demo and moving the lead on opens the next piece of work" do
    resolve_demo(next_step: "stage", next_stage: "proposal")

    assert @demo_ticket.reload.resolved?
    assert @lead.reload.proposal?
    assert @lead.tickets.proposal.exists?
  end

  test "resolving the demo while the customer goes quiet schedules the chase" do
    resolve_demo(next_step: "awaiting_customer", followup_on: "2026-10-09T11:00")

    assert @demo_ticket.reload.resolved?
    assert @lead.reload.awaiting_customer?
    assert @lead.demo?
    assert_equal Time.zone.local(2026, 10, 9, 11), @lead.followups.pending.sole.scheduled_for
  end

  test "awaiting the customer without a followup date changes nothing" do
    resolve_demo(next_step: "awaiting_customer", followup_on: "")

    assert_not @demo_ticket.reload.resolved?
    assert_not @lead.reload.awaiting_customer?
    assert_match "Scheduled for can't be blank", flash[:alert]
  end

  test "resolving with nothing next just resolves the ticket" do
    resolve_demo(next_step: "none")

    assert @demo_ticket.reload.resolved?
    assert @lead.reload.demo?
  end

  test "the ticket's dialog asks what's next only for a lead's demo or proposal ticket" do
    get "/forefront/tickets/#{@demo_ticket.id}"
    assert_select "input[type=radio][name='status_history[next_step]']", 3

    other = Forefront::Ticket.create!(title: "Bug", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                      category: "issue", priority: "low", status: "open")
    get "/forefront/tickets/#{other.id}"
    assert_select "input[name='status_history[next_step]']", 0
  end

  test "the lead page says when the demo was done" do
    travel_to Time.zone.local(2026, 10, 3, 15) do
      resolve_demo(next_step: "none")
    end

    get "/forefront/leads/#{@lead.id}"
    assert_match "Demo done 3 Oct", response.body
  end
end
