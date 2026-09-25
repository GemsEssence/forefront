require "test_helper"

class Forefront::LeadCsvExportRequestTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @open_lead = Forefront::Lead.create!(title: "Open Lead", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open", product: @product)
    @won_lead = Forefront::Lead.create!(title: "Won Lead", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "won", actual_amount: 100, product: @product)
    sign_in_as(@admin)
  end

  test "downloads a CSV of all leads visible to the current admin" do
    get "/forefront/leads.csv"

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "Open Lead", response.body
    assert_match "Won Lead", response.body
  end

  test "the CSV respects the current filters" do
    get "/forefront/leads.csv", params: { status: "Won" }

    assert_response :success
    assert_match "Won Lead", response.body
    assert_no_match "Open Lead", response.body
  end
end
