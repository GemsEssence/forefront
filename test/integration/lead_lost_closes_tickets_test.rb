require "test_helper"

class Forefront::LeadLostClosesTicketsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, status: "proposal")
    @open_ticket = ticket("Send proposal", "open")
    @done_ticket = ticket("Schedule demo", "resolved")
    @price = Forefront::LostReason.create!(name: "Price")
    sign_in_as(@rep)
  end

  def ticket(title, status)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, lead: @lead, created_by: @rep, assigned_to: @rep,
                              category: "proposal", priority: "medium", status: status)
  end

  test "losing a lead closes its open tickets and says why" do
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "lost", lost_reason_id: @price.id, note: "Too dear" } }

    assert @open_ticket.reload.closed?
    assert_equal "Closed because the lead was lost (Price)", @open_ticket.status_histories.last.note
    assert @done_ticket.reload.resolved?
  end

  test "winning a lead leaves its open tickets open" do
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "won", actual_amount: "500" } }

    assert @open_ticket.reload.open?
  end
end
