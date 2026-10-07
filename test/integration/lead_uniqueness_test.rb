require "test_helper"

# A Customer has at most one unfinished Lead per Product (CONTEXT.md). A
# Lost Lead is reopened, never duplicated; a Won one may sit beside a later
# Reclaim.
class Forefront::LeadUniquenessTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = forefront_product(allocated_to: @rep)
    @other_product = forefront_product("Gadget", allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    sign_in_as(@rep)
  end

  def existing_lead(status, **attrs)
    Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product, status: status, **attrs)
  end

  def create_lead(product: @product)
    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: "Second", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: product.id }, first_step: forefront_first_step }
  end

  test "a second lead can't be opened while the customer's lead for that product is unfinished" do
    lead = existing_lead("proposal")

    create_lead

    assert_response :unprocessable_entity
    assert_match "Acme already has an unfinished lead for Widget: Big Deal", response.body
    assert_select "a[href='/forefront/leads/#{lead.id}']", text: "Big Deal"
    assert_nil Forefront::Lead.find_by(title: "Second")
  end

  test "a lost lead is reopened by a manager, not replaced" do
    lead = existing_lead("lost", lost_reason: Forefront::LostReason.find_or_create_by!(name: "Price"), lost_note: "Too dear")

    create_lead

    assert_response :unprocessable_entity
    assert_match "Acme&#39;s lead for Widget was lost: Big Deal. Ask a Manager to reopen it", response.body
    assert_select "a[href='/forefront/leads/#{lead.id}']", text: "Big Deal"
    assert_nil Forefront::Lead.find_by(title: "Second")
  end

  test "a won lead doesn't block a fresh one for the same customer and product" do
    existing_lead("won", actual_amount: 100)

    create_lead

    assert_redirected_to "/forefront/leads/#{Forefront::Lead.find_by!(title: 'Second').id}"
  end

  test "the same customer may have an unfinished lead for each product" do
    existing_lead("proposal")

    create_lead(product: @other_product)

    assert_redirected_to "/forefront/leads/#{Forefront::Lead.find_by!(title: 'Second').id}"
  end

  test "a ticket can't be converted while the customer's lead for that product is unfinished" do
    existing_lead("open")
    ticket = Forefront::Ticket.create!(title: "Call", description: "D", customer: @customer, product: @product, created_by: @rep,
                                       assigned_to: @rep, category: "enquiry", priority: "medium", status: "open")

    post "/forefront/tickets/#{ticket.id}/conversion", params: { lead: { title: "Second", source_id: forefront_source.id }, first_step: forefront_first_step }

    assert_redirected_to "/forefront/tickets/#{ticket.id}"
    assert_equal "Acme already has an unfinished lead for Widget: Big Deal", flash[:alert]
    assert ticket.reload.open?
    assert_nil Forefront::Lead.find_by(title: "Second")
  end
end
