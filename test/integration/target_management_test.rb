require "test_helper"

class Forefront::TargetManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "an admin can create a target for a sales person and see it in the index" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    sign_in_as(admin)

    get "/forefront/targets"
    assert_response :success

    get "/forefront/targets/new"
    assert_response :success

    assert_difference "Forefront::Target.count", 1 do
      post "/forefront/targets", params: { target: { admin_id: rep.id, product_id: product.id, metric: "amount", goal_value: "1000", period: "monthly", starts_on: "2026-03-01" } }
    end
    assert_redirected_to "/forefront/targets"

    get "/forefront/targets"
    assert_match "Rep", response.body
    assert_match "Widget", response.body
  end

  test "a sales person can see only their own targets" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    Forefront::Target.create!(admin: rep, product: product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 1))
    Forefront::Target.create!(admin: other_rep, product: product, metric: "amount", goal_value: 500, period: "monthly", starts_on: Date.new(2026, 3, 1))
    sign_in_as(rep)

    get "/forefront/targets"
    assert_response :success
    assert_match "Rep", response.body
    assert_no_match "Other Rep", response.body

    get "/forefront/targets/new"
    assert_redirected_to "/forefront/"
  end

  test "an invalid starts_on is rejected with a clear error" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    sign_in_as(admin)

    assert_no_difference "Forefront::Target.count" do
      post "/forefront/targets", params: { target: { admin_id: rep.id, product_id: product.id, metric: "amount", goal_value: "1000", period: "monthly", starts_on: "2026-03-15" } }
    end
    assert_response :unprocessable_entity
  end
end
