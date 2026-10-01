require "test_helper"

class Forefront::LeadTicketsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "contacted")
    sign_in_as(@rep)
  end

  def ticket_params(**overrides)
    { title: "Send the proposal", description: "Pricing for 20 seats", category: "proposal", priority: "high", status: "open",
      customer_id: @customer.id, product_id: @product.id, lead_id: @lead.id }.merge(overrides)
  end

  test "the lead page links to a new ticket for this lead, pre-filled from the lead" do
    get "/forefront/leads/#{@lead.id}"
    assert_select "a[href='/forefront/tickets/new?lead_id=#{@lead.id}']", text: "New Ticket for this Lead"

    get "/forefront/tickets/new", params: { lead_id: @lead.id }
    assert_select "input[type=hidden][name='ticket[lead_id]'][value='#{@lead.id}']"
    assert_select "select[name='ticket[customer_id]'] option[selected]", text: "Acme"
    assert_select "select[name='ticket[product_id]'] option[selected]", text: "Widget"
    assert_select "select[name='ticket[assigned_to_id]'] option[selected]", text: "Ravi Rep"
  end

  test "a ticket created for a lead is listed on the lead and links back to it" do
    post "/forefront/tickets", params: { ticket: ticket_params }
    ticket = Forefront::Ticket.find_by!(title: "Send the proposal")

    get "/forefront/leads/#{@lead.id}"
    assert_select "#lead_tickets a[href='/forefront/tickets/#{ticket.id}']", text: "Send the proposal"

    get "/forefront/tickets/#{ticket.id}"
    assert_select "a[href='/forefront/leads/#{@lead.id}']", text: "Big Deal"
  end

  test "a ticket under a lead must be for the lead's customer and product" do
    other_customer = Forefront::Customer.create!(name: "Globex", phone: "555-0199")
    post "/forefront/tickets", params: { ticket: ticket_params(customer_id: other_customer.id, product_id: "") }

    assert_response :unprocessable_entity
    assert_match "Customer must be the lead&#39;s customer", response.body
    assert_match "Product must be the lead&#39;s product", response.body
  end

  test "a renewal ticket can't belong to a lead" do
    post "/forefront/tickets", params: { ticket: ticket_params(category: "plan_expired") }

    assert_response :unprocessable_entity
    assert_match "A renewal ticket can&#39;t belong to a lead", response.body
  end

  test "tickets offer a proposal category" do
    get "/forefront/tickets/new"

    assert_select "select[name='ticket[category]'] option[value=proposal]", text: "Proposal"
  end

  test "a ticket can't be put under a lead the sales person can't see" do
    other_rep = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product.admins << other_rep
    others_lead = Forefront::Lead.create!(title: "Meera's Deal", description: "D", customer: @customer, created_by: other_rep, assigned_to: other_rep,
                                          source: forefront_source, product: @product, status: "contacted")

    post "/forefront/tickets", params: { ticket: ticket_params(lead_id: others_lead.id) }

    assert_response :unprocessable_entity
    assert_empty others_lead.tickets
  end
end
