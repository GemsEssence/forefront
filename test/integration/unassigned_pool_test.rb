require "test_helper"

class Forefront::UnassignedPoolTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @widget = Forefront::Product.create!(name: "Widget")
    @gadget = Forefront::Product.create!(name: "Gadget")
    @widget.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    system = Forefront::Admin.system_actor
    @widget_ticket = pool_ticket("Call Acme about Widget", @widget, system)
    @gadget_ticket = pool_ticket("Call Acme about Gadget", @gadget, system)
    @widget_lead = Forefront::Lead.create!(title: "Widget deal", description: "D", customer: @customer, created_by: @manager,
                                           source: forefront_source, product: @widget, status: "open")
  end

  def pool_ticket(title, product, creator)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, product: product, created_by: creator,
                              category: "signup", priority: "high", status: "open")
  end

  test "a sales person sees the unassigned work for products allocated to them" do
    sign_in_as(@rep)
    get "/forefront/unassigned"

    assert_response :success
    assert_match "Call Acme about Widget", response.body
    assert_match "Widget deal", response.body
    assert_no_match "Call Acme about Gadget", response.body

    get "/forefront/tickets/#{@widget_ticket.id}"
    assert_response :success
  end

  test "a sales person can't see unassigned work for a product they're not allocated" do
    sign_in_as(@rep)

    get "/forefront/tickets/#{@gadget_ticket.id}"

    assert_redirected_to "/forefront/"
  end

  test "a sales person takes a ticket from the pool and it's theirs, recorded as an assignment" do
    sign_in_as(@rep)

    post "/forefront/tickets/#{@widget_ticket.id}/take"

    assert_equal @rep, @widget_ticket.reload.assigned_to
    assert_equal [ [ nil, @rep.id, @rep.id ] ], @widget_ticket.assignments.pluck(:from_user_id, :to_user_id, :changed_by_id)
    get "/forefront/unassigned"
    assert_no_match "Call Acme about Widget", response.body
  end

  test "a sales person takes a lead from the pool" do
    sign_in_as(@rep)

    post "/forefront/leads/#{@widget_lead.id}/take"

    assert_equal @rep, @widget_lead.reload.assigned_to
  end

  test "work that's already someone's, or for another product, can't be taken" do
    other_rep = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @widget.admins << other_rep
    @widget_ticket.update!(assigned_to: other_rep)
    sign_in_as(@rep)

    post "/forefront/tickets/#{@widget_ticket.id}/take"
    assert_equal other_rep, @widget_ticket.reload.assigned_to

    post "/forefront/tickets/#{@gadget_ticket.id}/take"
    assert_nil @gadget_ticket.reload.assigned_to
  end

  test "a manager sees the whole pool and assigns from it" do
    sign_in_as(@manager)
    get "/forefront/unassigned"
    assert_match "Call Acme about Widget", response.body
    assert_match "Call Acme about Gadget", response.body

    get "/forefront/tickets/#{@gadget_ticket.id}"
    assert_select "button", text: "Change Assignee"
    post "/forefront/tickets/#{@gadget_ticket.id}/assignments", params: { assignment: { to_user_id: @rep.id } }

    assert_equal @rep, @gadget_ticket.reload.assigned_to
  end

  test "the page offers Take to a sales person and a manager, and Assign to an admin" do
    sign_in_as(@rep)
    get "/forefront/unassigned"
    assert_select "form[action='/forefront/tickets/#{@widget_ticket.id}/take'] button", text: "Take"

    sign_in_as(@manager)
    get "/forefront/unassigned"
    assert_select "form[action='/forefront/tickets/#{@gadget_ticket.id}/take'] button", text: "Take"

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(admin)
    get "/forefront/unassigned"
    assert_select "a[href='/forefront/tickets/#{@widget_ticket.id}']", text: "Assign"
  end
end
