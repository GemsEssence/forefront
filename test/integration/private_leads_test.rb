require "test_helper"

# A Lead created by hand in the Lead form is private (CONTEXT.md: Private
# Lead): hidden from the owner's Manager until it is Won, Lost or shared.
# Admins see everything.
class Forefront::PrivateLeadsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @other_rep = dashboard_staff("Meera Rep", "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: [ @rep, @other_rep ])
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def create_lead(as:, title: "Secret deal", **attrs)
    sign_in_as(as)
    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: title, description: "D", customer_id: @customer.id, source_id: forefront_source.id,
                                               product_id: @product.id, **attrs } }
    Forefront::Lead.find_by(title: title)
  end

  def private_lead(title: "Secret deal", customer: @customer, created_at: Time.current)
    Forefront::Lead.create!(title: title, description: "D", customer: customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product, status: "open", private: true, created_at: created_at)
  end

  test "a lead a sales person creates in the form is private: hidden from their manager, seen by an admin" do
    sign_in_as(@rep)
    get "/forefront/leads/new"
    assert_select "input[type=checkbox][name='lead[private]'][checked]"

    lead = create_lead(as: @rep, private: "1")
    assert lead.private?

    sign_in_as(@manager)
    get "/forefront/leads"
    assert_no_match "Secret deal", response.body
    get "/forefront/leads/#{lead.id}"
    assert_redirected_to "/forefront/"
    get "/forefront/"
    assert_equal "0", metric(:pipeline, slice: "open")
    get "/forefront/reports/lead_stage"
    assert_no_match "Secret deal", response.body

    sign_in_as(@admin)
    get "/forefront/leads"
    assert_match "Secret deal", response.body
  end

  test "an admin's new lead isn't private, and a lead converted from a ticket never is" do
    sign_in_as(@admin)
    get "/forefront/leads/new"
    assert_select "input[name='lead[private]']", count: 0

    ticket = Forefront::Ticket.create!(title: "Call", description: "D", customer: @customer, product: @product, created_by: @rep,
                                       assigned_to: @rep, category: "enquiry", priority: "medium", status: "open")
    sign_in_as(@rep)
    post "/forefront/tickets/#{ticket.id}/conversion", params: { lead: { title: "Converted", source_id: forefront_source.id } }

    assert_not Forefront::Lead.find_by!(title: "Converted").private?
  end

  test "privacy ends when the lead is won or lost" do
    won = private_lead(title: "Won deal")
    lost = private_lead(title: "Lost deal", customer: Forefront::Customer.create!(name: "Globex", phone: "555-0199"))
    sign_in_as(@rep)
    post "/forefront/leads/#{won.id}/status_histories", params: { status_history: { status: "won", actual_amount: "100" } }
    post "/forefront/leads/#{lost.id}/status_histories",
         params: { status_history: { status: "lost", lost_reason_id: Forefront::LostReason.find_or_create_by!(name: "Price").id, note: "Too dear" } }

    assert_not won.reload.private?
    assert_not lost.reload.private?
    sign_in_as(@manager)
    get "/forefront/leads"
    assert_match "Won deal", response.body
    assert_match "Lost deal", response.body
  end

  test "the owner can make a private lead visible from the edit form" do
    lead = private_lead
    sign_in_as(@rep)

    patch "/forefront/leads/#{lead.id}", params: { lead: { private: "0" } }

    assert_not lead.reload.private?
    sign_in_as(@manager)
    get "/forefront/leads/#{lead.id}"
    assert_response :success
  end

  test "a private lead is always assigned, and changes hands only through an admin" do
    unassigned = Forefront::Lead.new(title: "Nobody's", description: "D", customer: @customer, created_by: @rep, source: forefront_source,
                                     product: @product, status: "open", private: true)
    assert_not unassigned.valid?
    assert_includes unassigned.errors[:base], "A private lead must be assigned"

    lead = private_lead
    sign_in_as(@manager)
    post "/forefront/leads/#{lead.id}/assignments", params: { assignment: { to_user_id: @other_rep.id } }
    assert_equal @rep, lead.reload.assigned_to

    sign_in_as(@admin)
    post "/forefront/leads/#{lead.id}/assignments", params: { assignment: { to_user_id: @other_rep.id } }
    assert_equal @other_rep, lead.reload.assigned_to
  end

  test "stale alerts about a private lead go to the owner alone, not their manager" do
    secret = private_lead(created_at: 3.days.ago)
    open = Forefront::Lead.create!(title: "Open deal", description: "D", customer: Forefront::Customer.create!(name: "Globex", phone: "555-0199"),
                                   created_by: @rep, assigned_to: @rep, source: forefront_source, product: @product, status: "open", created_at: 3.days.ago)

    Forefront::NotificationOperations::Sweep.new.call

    assert_equal [ @rep.id ], Forefront::Notification.where(kind: "stale", subject: secret).pluck(:recipient_id)
    assert_equal [ @rep.id, @manager.id ].sort, Forefront::Notification.where(kind: "stale", subject: open).pluck(:recipient_id).sort
  end
end
