require "test_helper"

class Forefront::LeadAwaitingCustomerTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, status: "demo")
    sign_in_as(@rep)
  end

  def await_customer(scheduled_for: 3.days.from_now.change(hour: 11))
    post "/forefront/leads/#{@lead.id}/awaiting_customer",
         params: { followup: { followup_type: "call", scheduled_for: scheduled_for, outcome: "Chase after the demo" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }
  end

  test "marking a lead as awaiting the customer schedules a followup and shows on the lead" do
    travel_to Time.zone.local(2026, 10, 3, 10) do
      await_customer(scheduled_for: Time.zone.local(2026, 10, 6, 11))

      assert @lead.reload.awaiting_customer?
      followup = @lead.followups.last
      assert_equal Time.zone.local(2026, 10, 6, 11), followup.scheduled_for
      assert_equal @rep, followup.assigned_to

      get "/forefront/leads/#{@lead.id}"
      assert_match "Awaiting customer since 3 Oct", response.body
      assert_match "Next followup 6 Oct", response.body
    end
  end

  test "a lead can't be marked awaiting without a followup date" do
    await_customer(scheduled_for: "")

    assert_not @lead.reload.awaiting_customer?
    assert_match "Scheduled for can't be blank", flash[:alert]
  end

  test "the customer responding clears the flag" do
    await_customer

    delete "/forefront/leads/#{@lead.id}/awaiting_customer", headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }

    assert_not @lead.reload.awaiting_customer?
  end

  test "changing the stage clears the flag" do
    await_customer

    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "proposal" } }

    assert_not @lead.reload.awaiting_customer?
  end

  test "a won or lost lead can't be awaiting the customer" do
    @lead.update!(status: "won", actual_amount: 100)

    await_customer

    assert_not @lead.reload.awaiting_customer?
    assert_match "Only a lead still being worked can be awaiting the customer", flash[:alert]
  end

  test "marking and clearing are audited" do
    await_customer
    delete "/forefront/leads/#{@lead.id}/awaiting_customer"

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    delete "/forefront/admins/sign_out"
    sign_in_as(admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*marked awaiting customer.*Lead.*Big Deal/m
    assert_select "tr", text: /Ravi Rep.*customer responded.*Lead.*Big Deal/m
  end

  test "the lead page offers Customer went quiet while the lead is being worked" do
    get "/forefront/leads/#{@lead.id}"

    assert_select "[data-stage-actions] button", text: "Customer went quiet"
    assert_select "#stage_action_modal_lead_#{@lead.id}_quiet input[name='stage_action[scheduled_for]'][required]"
  end
end
