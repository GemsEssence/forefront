require "test_helper"

class Forefront::DashboardTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    product = Forefront::Product.create!(name: "Widget")
    product.admins << @rep
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: "website", status: "won", actual_amount: 100, product: product)
    Forefront::Payment.create!(lead: lead, total_amount: 500, status: "paid", paid_at: Time.current)
  end

  test "an admin sees revenue and a leaderboard" do
    sign_in_as(@admin)

    get "/forefront/"
    assert_response :success
    assert_match "Revenue Collected", response.body
    assert_match "$500.00", response.body
    assert_match "Leaderboard", response.body
    assert_match "Rep", response.body
  end

  test "a sales person sees their own numbers but no leaderboard" do
    sign_in_as(@rep)

    get "/forefront/"
    assert_response :success
    assert_match "$500.00", response.body
    assert_no_match "Leaderboard", response.body
  end

  test "an admin can filter the dashboard to a date range that excludes the win" do
    sign_in_as(@admin)

    get "/forefront/", params: { from: 10.years.ago.to_date, to: 5.years.ago.to_date }
    assert_response :success
    assert_match "$0.00", response.body
    assert_no_match "$500.00", response.body
  end

  test "an admin can filter the dashboard to a date range that includes the win" do
    sign_in_as(@admin)

    get "/forefront/", params: { from: 1.day.ago.to_date, to: 1.day.from_now.to_date }
    assert_response :success
    assert_match "$500.00", response.body
  end
end
