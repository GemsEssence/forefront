require "test_helper"

class Forefront::AuditLogTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  test "creating a lead shows up in the audit log for an admin" do
    sign_in_as(@rep)
    post "/forefront/leads", params: { lead: { title: "Big Deal", description: "D", customer_id: @customer.id, source: "website", status: "open" } }

    sign_in_as(@admin)
    get "/forefront/audit_log"

    assert_response :success
    assert_select "tr", text: /Ravi Rep.*created.*Lead.*Big Deal/m
  end

  test "updating a lead records what changed, before and after" do
    lead = Forefront::Lead.create!(title: "Old title", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open")

    sign_in_as(@rep)
    patch "/forefront/leads/#{lead.id}", params: { lead: { title: "New title" } }

    sign_in_as(@admin)
    get "/forefront/audit_log"

    assert_select "tr", text: /Ravi Rep.*updated.*Lead.*New title.*Title: Old title → New title/m
  end

  test "deleting a lead is still readable in the log after the lead is gone" do
    lead = Forefront::Lead.create!(title: "Doomed", description: "D", customer: @customer, created_by: @rep, source: "website", status: "open")

    sign_in_as(@admin)
    delete "/forefront/leads/#{lead.id}"
    get "/forefront/audit_log"

    assert_select "tr", text: /Asha Admin.*deleted.*Lead.*Doomed/m
  end

  test "a sales person can't open the audit log" do
    sign_in_as(@rep)
    get "/forefront/audit_log"

    assert_redirected_to "/forefront/"
    assert_match "not authorized", flash[:alert]
  end

  test "creating, updating and deleting a ticket are all recorded" do
    sign_in_as(@admin)
    post "/forefront/tickets", params: { ticket: { title: "Call back", description: "D", customer_id: @customer.id, category: "demo", priority: "high", status: "open" } }
    ticket = Forefront::Ticket.find_by!(title: "Call back")
    patch "/forefront/tickets/#{ticket.id}", params: { ticket: { priority: "low" } }
    delete "/forefront/tickets/#{ticket.id}"

    get "/forefront/audit_log"

    assert_select "tr", text: /created.*Ticket.*Call back/m
    assert_select "tr", text: /updated.*Ticket.*Call back.*Priority: high → low/m
    assert_select "tr", text: /deleted.*Ticket.*Call back/m
  end

  test "creating, updating and deleting a customer are all recorded" do
    sign_in_as(@admin)
    post "/forefront/customers", params: { customer: { name: "Globex", phone: "555-0199" } }
    customer = Forefront::Customer.find_by!(name: "Globex")
    patch "/forefront/customers/#{customer.id}", params: { customer: { business_name: "Globex Corp" } }
    delete "/forefront/customers/#{customer.id}"

    get "/forefront/audit_log"

    assert_select "tr", text: /Asha Admin.*created.*Customer.*Globex/m
    assert_select "tr", text: /updated.*Customer.*Globex.*Business name: — → Globex Corp/m
    assert_select "tr", text: /deleted.*Customer.*Globex/m
  end
end
