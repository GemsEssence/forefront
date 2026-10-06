require "test_helper"

# A Lead is a journey with exactly one Product (CONTEXT.md), so the form
# and the Ticket conversion both insist on one. Leads that already exist
# without a Product are left alone.
class Forefront::LeadProductRequiredTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @product = Forefront::Product.create!(name: "Widget")
    sign_in_as(@admin)
  end

  test "a lead can't be created without a product" do
    post "/forefront/leads", params: { lead: { title: "Big Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: "" } }

    assert_response :unprocessable_entity
    assert_match "Product can&#39;t be blank", response.body
    assert_nil Forefront::Lead.find_by(title: "Big Deal")
  end

  test "a ticket without a product can't be converted into a lead" do
    ticket = Forefront::Ticket.create!(title: "Call", description: "D", customer: @customer, created_by: @admin, category: "enquiry", priority: "medium", status: "open")

    post "/forefront/tickets/#{ticket.id}/conversion", params: { lead: { title: "Big Deal", source_id: forefront_source.id } }

    assert_redirected_to "/forefront/tickets/#{ticket.id}"
    assert_equal "Product can't be blank", flash[:alert]
    assert ticket.reload.open?
    assert_nil Forefront::Lead.find_by(title: "Big Deal")
  end

  test "an existing lead without a product can still be edited" do
    lead = Forefront::Lead.create!(title: "Old", description: "D", customer: @customer, created_by: @admin, source: forefront_source)

    patch "/forefront/leads/#{lead.id}", params: { lead: { title: "Old, renamed" } }

    assert_redirected_to "/forefront/leads/#{lead.id}"
    assert_equal "Old, renamed", lead.reload.title
  end
end
