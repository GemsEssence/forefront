require "test_helper"

class Forefront::CoreWorkflowsTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")

    # The very first request against a freshly booted engine route set can 404
    # before routes finish lazily loading; warm them up before signing in.
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "creating, viewing, and listing a ticket works end to end" do
    post "/forefront/tickets", params: { ticket: { title: "Schedule demo", description: "Wants a demo", customer_id: @customer.id, category: "new_app_demo", priority: "medium" } }
    ticket = Forefront::Ticket.last

    assert_redirected_to "/forefront/tickets/#{ticket.id}"
    assert ticket.open?

    get "/forefront/tickets/#{ticket.id}"
    assert_response :success

    get "/forefront/tickets"
    assert_response :success
  end

  test "creating, viewing, and listing a lead works end to end" do
    post "/forefront/leads", params: { lead: { title: "New prospect", description: "Inbound", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product(allocated_to: @admin).id } }
    lead = Forefront::Lead.last

    assert_redirected_to "/forefront/leads/#{lead.id}"
    assert lead.open?

    get "/forefront/leads/#{lead.id}"
    assert_response :success

    get "/forefront/leads"
    assert_response :success
  end

  test "creating a customer works end to end" do
    post "/forefront/customers", params: { customer: { name: "New Co", email: "newco-#{SecureRandom.hex(4)}@example.com", phone: "555-0199" } }

    assert_response :redirect
  end

  test "scheduling a followup on a lead works end to end" do
    post "/forefront/leads", params: { lead: { title: "New prospect", description: "Inbound", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product(allocated_to: @admin).id } }
    lead = Forefront::Lead.last

    post "/forefront/leads/#{lead.id}/followups", params: { followup: { followup_type: "call", assigned_to_id: @admin.id, scheduled_for: 1.day.from_now } }

    assert_response :redirect
    assert_equal 1, lead.followups.count
  end

  test "reassigning a ticket works end to end" do
    other_admin = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123")
    post "/forefront/tickets", params: { ticket: { title: "T", description: "D", customer_id: @customer.id, category: "new_app_demo", priority: "medium" } }
    ticket = Forefront::Ticket.last

    post "/forefront/tickets/#{ticket.id}/assignments", params: { assignment: { to_user_id: other_admin.id } }

    assert_response :redirect
    assert_equal other_admin.id, ticket.reload.assigned_to_id
  end
end
