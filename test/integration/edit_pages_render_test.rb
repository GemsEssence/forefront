require "test_helper"

class Forefront::EditPagesRenderTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    sign_in_as(@admin)
  end

  test "the lead edit page renders" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "open")
    get "/forefront/leads/#{lead.id}/edit"
    assert_response :success
  end

  test "the ticket edit page renders" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "issue", priority: "medium", status: "open")
    get "/forefront/tickets/#{ticket.id}/edit"
    assert_response :success
  end

  test "the customer edit page renders" do
    get "/forefront/customers/#{@customer.id}/edit"
    assert_response :success
  end
end
