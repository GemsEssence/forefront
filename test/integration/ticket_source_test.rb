require "test_helper"

# Where a Customer came from (CONTEXT.md: Source) is read off the Tickets
# and Leads they came in through, so a Ticket records a Source too: typed
# on the form, or taken from the Signup, the Campaign or the Lead it's under.
class Forefront::TicketSourceTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", country_code: "+91", phone: "9876543210")
    @linkedin = forefront_source("LinkedIn")
    sign_in_as(@rep)
  end

  def ticket_params(**overrides)
    { title: "Call Acme", description: "D", customer_id: @customer.id, category: "enquiry", priority: "medium", product_id: @product.id,
      due_at: (Date.current + 5).iso8601 }.merge(overrides)
  end

  test "a ticket typed in by staff needs a source, shown on its page" do
    get "/forefront/tickets/new"
    assert_select "select[name='ticket[source_id]'][required] option", text: "LinkedIn"

    post "/forefront/tickets", params: { ticket: ticket_params(source_id: "") }
    assert_response :unprocessable_entity
    assert_match "Source can&#39;t be blank", response.body

    post "/forefront/tickets", params: { ticket: ticket_params(source_id: @linkedin.id) }
    ticket = Forefront::Ticket.find_by!(title: "Call Acme")
    assert_equal @linkedin, ticket.source
    get "/forefront/tickets/#{ticket.id}"
    assert_select "dt", text: "Source"
    assert_select "dd", text: "LinkedIn"
  end

  test "a signup, a campaign enquiry and a stage ticket take their source from where they came" do
    key = @product.generate_api_key!
    post "/forefront/api/v1/signup", params: { name: "Priya", country_code: "+91", phone: "5550199" }.to_json,
         headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{key}" }
    assert_equal "Signup", Forefront::Ticket.signup.sole.source.name

    campaign = Forefront::Campaign.create!(name: "Gitex 2026", starts_on: Date.current - 1, ends_on: Date.current + 30, source: forefront_source("Gitex"), created_by: @rep)
    post "/forefront/campaigns/#{campaign.id}/enquiries", params: { enquiry: { name: "Acme", country_code: "+91", phone: "9876543210", product_id: @product.id, note: "Asked at the stand" } }
    assert_equal "Gitex", @customer.tickets.enquiry.sole.source.name

    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: @linkedin,
                                   product: @product, status: "contacted", due_at: Date.current + 10)
    post "/forefront/leads/#{lead.id}/stage_action", params: { stage_action: { kind: "demo", ticket_due_at: (Date.current + 2).iso8601 } }
    assert_equal @linkedin, lead.tickets.new_app_demo.sole.source
  end

  test "converting a ticket pre-selects the ticket's own source" do
    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 5, source: @linkedin)

    get "/forefront/tickets/#{ticket.id}"

    assert_select "form[action='/forefront/tickets/#{ticket.id}/conversion'] select[name='lead[source_id]'] option[selected]", text: "LinkedIn"
  end

  test "the customer page says where they first heard of us, from their earliest ticket or lead" do
    travel_to Time.zone.local(2026, 9, 1, 10) do
      Forefront::Ticket.create!(title: "First call", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                category: "enquiry", priority: "medium", status: "resolved", due_at: Date.current + 5, source: forefront_source("Referral"))
    end
    Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: @linkedin,
                            product: @product, status: "contacted", due_at: Date.current + 10)

    get "/forefront/customers/#{@customer.id}"

    assert_select "dt", text: "First heard of us via"
    assert_select "dd", text: /Referral/
  end
end
