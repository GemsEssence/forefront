require "test_helper"

# Only the assignee works a Lead or Ticket (CONTEXT.md). A Manager leaves
# notes, reassigns, reopens, shares and corrects the stage; an Admin
# creates, assigns, reopens and reads, and never works a record.
class Forefront::WhoActsTest < ActionDispatch::IntegrationTest
  NOT_AUTHORIZED = "You are not authorized to perform this action."

  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @creator = Forefront::Admin.create!(name: "Carl Creator", email: "carl-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: [ @rep, @creator ])
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @creator, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "contacted", due_at: Date.current + 10)
    @ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @creator,
                                        assigned_to: @rep, category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5)
  end

  def note(record)
    post "/forefront/#{record.model_name.route_key}/#{record.id}/activities", params: { activity: { activity_type: "comment", body: "A note" } }
  end

  def followup(record)
    post "/forefront/#{record.model_name.route_key}/#{record.id}/followups", params: { followup: { followup_type: "call", scheduled_for: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") } }
  end

  def change_status(record, status)
    post "/forefront/#{record.model_name.route_key}/#{record.id}/status_histories", params: { status_history: { status: status } }
  end

  test "the assignee works the lead: note, followup, stage, payment" do
    sign_in_as(@rep)
    get "/forefront/leads/#{@lead.id}"
    assert_match "Add Activity", response.body
    assert_match "+ Add Followup", response.body
    assert_select "button", text: "Change Stage"

    note(@lead)
    followup(@lead)
    change_status(@lead, "negotiation")
    assert_equal [ 1, 1, true ], [ @lead.activities.count, @lead.followups.count, @lead.reload.negotiation? ]
    change_status(@lead, "won")
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "won", actual_amount: "500" } }
    post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: "500" } }
    assert @lead.reload.payment.present?
  end

  test "an admin can read and reassign a lead but never works it" do
    sign_in_as(@admin)
    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_no_match "Add Activity", response.body
    assert_no_match "+ Add Followup", response.body
    assert_select "button", text: "Change Stage", count: 0
    assert_select "button", text: "Change Assignee"

    note(@lead)
    assert_equal NOT_AUTHORIZED, flash[:alert]
    followup(@lead)
    change_status(@lead, "negotiation")
    assert_equal [ 0, 0, true ], [ @lead.activities.count, @lead.followups.count, @lead.reload.contacted? ]
  end

  test "a manager leaves a note and may move the stage to correct it, but doesn't do the day-to-day work" do
    sign_in_as(@manager)
    get "/forefront/leads/#{@lead.id}"
    assert_match "Add Activity", response.body
    assert_no_match "+ Add Followup", response.body
    assert_select "button", text: "Move stage"

    note(@lead)
    assert_equal 1, @lead.activities.count
    followup(@lead)
    assert_equal 0, @lead.followups.count
    change_status(@lead, "negotiation")
    assert @lead.reload.negotiation?
    @lead.update!(status: "won", actual_amount: 500)
    post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: "500" } }
    assert_nil @lead.reload.payment
  end

  test "the creator who handed the lead on can't work it any more" do
    sign_in_as(@creator)
    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_no_match "Add Activity", response.body

    note(@lead)
    change_status(@lead, "negotiation")
    assert_equal [ 0, true ], [ @lead.activities.count, @lead.reload.contacted? ]
  end

  test "the same holds for a ticket" do
    sign_in_as(@admin)
    note(@ticket)
    change_status(@ticket, "in_progress")
    assert_equal [ 0, true ], [ @ticket.activities.count, @ticket.reload.open? ]

    sign_in_as(@manager)
    note(@ticket)
    followup(@ticket)
    change_status(@ticket, "in_progress")
    assert_equal [ 1, 0, true ], [ @ticket.activities.count, @ticket.followups.count, @ticket.reload.in_progress? ]

    sign_in_as(@rep)
    followup(@ticket)
    assert_equal 1, @ticket.followups.count
  end

  test "an admin never creates a private lead" do
    sign_in_as(@admin)
    get "/forefront/leads/new"
    assert_select "input[name='lead[private]']", count: 0

    globex = Forefront::Customer.create!(name: "Globex", phone: "555-0199")
    post "/forefront/leads", params: { lead: { title: "Handed out", description: "D", customer_id: globex.id, source_id: forefront_source.id,
                                               product_id: @product.id, due_at: (Date.current + 7).iso8601, assigned_to_id: @rep.id, private: "1" } }

    assert_not Forefront::Lead.find_by!(title: "Handed out").private?
  end
end
