require "test_helper"

class Forefront::ContactRevealActionTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @other = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @priya = Forefront::Customer.create!(name: "Priya Shah", email: "priya@gmail.com", country_code: "+91", phone: "9876543210")
    @ticket = Forefront::Ticket.create!(title: "Call back", description: "D", customer: @priya, created_by: @rep, assigned_to: @rep,
                                        category: "request", priority: "medium", status: "open")
    sign_in_as(@rep)
  end

  def reveal
    post "/forefront/customers/#{@priya.id}/contact_reveal"
  end

  def reminder_shown?
    get "/forefront/customers/#{@priya.id}"
    css_select("[data-reveal-reminder]").any?
  end

  test "after revealing, the customer page reminds you to record what you did" do
    reveal

    get "/forefront/customers/#{@priya.id}"
    assert_select "[data-reveal-reminder]", text: /You revealed Priya Shah's contact details/
  end

  test "a comment on one of their tickets answers the reveal" do
    reveal
    post "/forefront/tickets/#{@ticket.id}/activities", params: { activity: { activity_type: "comment", body: "Called, they'll think about it" } }

    assert_not reminder_shown?
  end

  test "opening a ticket for them answers the reveal" do
    reveal
    post "/forefront/tickets", params: { ticket: { title: "Wants a demo", description: "D", customer_id: @priya.id, category: "new_app_demo", priority: "medium", status: "open" } }

    assert_not reminder_shown?
  end

  test "a followup on one of their leads answers the reveal" do
    lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: @priya, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "contacted")
    reveal
    post "/forefront/leads/#{lead.id}/followups", params: { followup: { followup_type: "call", scheduled_for: 2.days.from_now } }

    assert_not reminder_shown?
  end

  test "someone else's action doesn't answer my reveal" do
    reveal
    @ticket.update!(assigned_to: @other)
    sign_in_as(@other)
    post "/forefront/tickets/#{@ticket.id}/activities", params: { activity: { activity_type: "comment", body: "Mine" } }

    sign_in_as(@rep)
    assert reminder_shown?
  end

  test "an action from before the reveal doesn't count" do
    post "/forefront/tickets/#{@ticket.id}/activities", params: { activity: { activity_type: "comment", body: "Earlier" } }
    travel 1.minute do
      reveal
      assert reminder_shown?
    end
  end

  test "the reminder is only for whoever revealed" do
    reveal

    sign_in_as(@other)
    assert_not reminder_shown?
  end
end
