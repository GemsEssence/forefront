require "test_helper"

# A Sales person moves a Lead through stage actions (CONTEXT.md: Lead):
# buttons that depend on the stage, ask only for what they need, and always
# leave a next step. A Manager keeps a free "Move stage" to correct a Lead.
class Forefront::StageActionsTest < ActionDispatch::IntegrationTest
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
    @price = Forefront::LostReason.find_or_create_by!(name: "Price")
    travel_to Time.zone.local(2026, 10, 6, 9)
    @lead = lead("open")
    sign_in_as(@rep)
  end

  def lead(status)
    Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: status, due_at: Date.current + 20)
  end

  def act(kind, **fields)
    post "/forefront/leads/#{@lead.id}/stage_action", params: { stage_action: { kind: kind, **fields } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }
  end

  def buttons
    css_select("[data-stage-actions] button").map { |b| b.text.squish }
  end

  test "an open lead offers Customer reached, which moves it to Contacted with the next followup" do
    get "/forefront/leads/#{@lead.id}"
    assert_equal [ "Customer reached", "Lost" ], buttons
    assert_select "button", text: "Change Stage", count: 0

    act("contacted", followup_type: "call", scheduled_for: "2026-10-08T10:00", note: "Spoke to Priya")

    assert_redirected_to "/forefront/leads/#{@lead.id}"
    @lead.reload
    assert @lead.contacted?
    assert_equal Time.zone.local(2026, 10, 8, 10), @lead.followups.pending.sole.scheduled_for
    assert_equal "Spoke to Priya", @lead.status_histories.last.note
  end

  test "Customer reached without a followup date is refused, so the lead never lacks a next step" do
    act("contacted", followup_type: "call", scheduled_for: "")

    assert @lead.reload.open?
    assert_match "Scheduled for can't be blank", flash[:alert]
  end

  test "a contacted lead offers the sales actions; Schedule demo opens the demo ticket" do
    @lead.update!(status: "contacted")
    get "/forefront/leads/#{@lead.id}"
    assert_equal [ "Schedule demo", "Send proposal", "Customer went quiet", "Won", "Lost" ], buttons

    act("demo", ticket_due_at: "2026-10-09")

    @lead.reload
    assert @lead.demo?
    ticket = @lead.tickets.new_app_demo.sole
    assert_equal [ Date.new(2026, 10, 9), @rep ], [ ticket.due_at, ticket.assigned_to ]
    get "/forefront/leads/#{@lead.id}"
    assert_equal [ "Send proposal", "Customer went quiet", "Won", "Lost" ], buttons
    assert_select "[data-next-step]", text: /Schedule demo, due 9 Oct/
  end

  test "Customer went quiet schedules the chase and keeps the stage" do
    @lead.update!(status: "proposal")

    act("quiet", followup_type: "email", scheduled_for: "2026-10-10T09:00")

    @lead.reload
    assert @lead.proposal?
    assert @lead.awaiting_customer?
    assert_equal "email", @lead.followups.pending.sole.followup_type
  end

  test "Won asks for the actual amount and the expiry, and creates the subscription" do
    @lead.update!(status: "negotiation")

    act("won", actual_amount: "4500", expires_at: "2027-10-05")

    @lead.reload
    assert @lead.won?
    assert_equal [ 4500, Date.new(2027, 10, 5) ], [ @lead.actual_amount, @lead.subscription.expires_at ]
  end

  test "Lost needs a reason and a note" do
    @lead.update!(status: "contacted")
    act("lost", lost_reason_id: @price.id, note: "")
    assert @lead.reload.contacted?
    assert_match "Note is required when a lead is lost", flash[:alert]

    act("lost", lost_reason_id: @price.id, note: "Went with a cheaper vendor")
    assert @lead.reload.lost?
    assert_equal @price, @lead.lost_reason
  end

  test "a manager corrects with Move stage and sees no action buttons; an admin sees neither" do
    sign_in_as(@manager)
    get "/forefront/leads/#{@lead.id}"
    assert_empty buttons
    assert_select "button", text: "Move stage"

    sign_in_as(@admin)
    get "/forefront/leads/#{@lead.id}"
    assert_empty buttons
    assert_select "button", text: "Move stage", count: 0
    act("contacted", followup_type: "call", scheduled_for: "2026-10-08T10:00")
    assert @lead.reload.open?
  end
end
