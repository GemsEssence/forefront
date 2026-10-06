require "test_helper"

# The Lead page names the Product, says when the Lead is private, and shows
# both the expiry agreed at the sale and where the Subscription stands now.
class Forefront::LeadPageDetailsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    sign_in_as(@rep)
  end

  test "an open private lead shows its product and a Private badge" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, product: @product, status: "open", private: true)

    get "/forefront/leads/#{lead.id}"

    assert_select "dt", text: "Product"
    assert_select "dd", text: "Widget"
    assert_select "span", text: "Private"
  end

  test "a won lead shows the expiry agreed at the sale and the subscription's current expiry" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, product: @product, status: "won", actual_amount: 100, expires_at: Date.new(2027, 3, 31))
    lead.subscription.update!(expires_at: Date.new(2027, 9, 30))

    get "/forefront/leads/#{lead.id}"

    assert_select "dt", text: "Expiry at sale"
    assert_select "dd", text: "31 Mar 2027"
    assert_select "dt", text: "Subscription expires"
    assert_select "dd", text: "30 Sep 2027"
    assert_select "span", text: "Private", count: 0
  end
end
