require "test_helper"

class Forefront::TargetRewardManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "an admin can set reward and bonus terms on a target, and the index shows the payout once earned" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    product.admins << rep
    customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    sign_in_as(admin)

    post "/forefront/targets", params: { target: {
      admin_id: rep.id, product_id: product.id, metric: "amount", goal_value: "100",
      period: "monthly", starts_on: "2026-03-01",
      reward_type: "fixed", reward_value: "25", bonus_type: "percentage", bonus_value: "10"
    } }
    assert_redirected_to "/forefront/targets"

    target = Forefront::Target.order(:created_at).last
    assert target.reward_type_fixed?
    assert_equal 25, target.reward_value
    assert target.bonus_type_percentage?

    lead = Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: rep, assigned_to: rep, source: "website", status: "open", product: product)
    lead.update!(status: "won", actual_amount: 100)
    lead.update_column(:won_at, Time.utc(2026, 3, 10))

    get "/forefront/targets"
    assert_match "Payout", response.body
    assert_match "₹25.00", response.body
  end

  test "leaving reward/bonus blank on the form does not raise" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    sign_in_as(admin)

    assert_difference "Forefront::Target.count", 1 do
      post "/forefront/targets", params: { target: {
        admin_id: rep.id, product_id: product.id, metric: "amount", goal_value: "100",
        period: "monthly", starts_on: "2026-03-01", reward_type: "", bonus_type: ""
      } }
    end
    assert_redirected_to "/forefront/targets"
    assert_nil Forefront::Target.order(:created_at).last.reward_type
  end
end
