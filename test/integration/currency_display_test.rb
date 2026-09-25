require "test_helper"

class Forefront::CurrencyDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: @customer, created_by: @admin, source: "website", estimated_amount: 150_000)

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  teardown { Forefront.currency = "INR" }

  test "amounts show in rupees by default, and amount fields name the currency" do
    get "/forefront/leads/#{@lead.id}"
    assert_includes response.body, "₹1,50,000.00"
    assert_not_includes response.body, "$1"

    get "/forefront/leads/#{@lead.id}/edit"
    assert_select "label[for=lead_estimated_amount]", text: "Estimated Amount (₹)"
  end

  test "a host app can switch the currency" do
    Forefront.currency = "USD"

    get "/forefront/leads/#{@lead.id}"
    assert_includes response.body, "$150,000.00"
  end
end
