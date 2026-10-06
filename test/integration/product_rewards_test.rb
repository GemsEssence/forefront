require "test_helper"

# Renewal and Reclaim rewards are a percentage set per Product (CONTEXT.md).
# Until now nothing let an Admin set them, so every reward showed as zero.
class Forefront::ProductRewardsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @product = Forefront::Product.create!(name: "Widget")
  end

  test "an admin sets the renewal and reclaim reward percentages on the product form" do
    sign_in_as(@admin)
    get "/forefront/products/#{@product.id}/edit"
    assert_select "input[name='product[renewal_reward_percentage]']"
    assert_select "input[name='product[reclaim_reward_percentage]']"

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", renewal_reward_percentage: "10", reclaim_reward_percentage: "20" } }

    assert_equal [ 10, 20 ], [ @product.reload.renewal_reward_percentage, @product.reclaim_reward_percentage ]
    assert Forefront::AuditEvent.exists?(actor: @admin, action: "updated", auditable: @product)
  end

  test "a percentage must be between 0 and 100" do
    sign_in_as(@admin)

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", renewal_reward_percentage: "150" } }

    assert_response :unprocessable_entity
    assert_nil @product.reload.renewal_reward_percentage
  end

  test "a manager neither sees nor sets them" do
    sign_in_as(@manager)
    get "/forefront/products/#{@product.id}/edit"
    assert_select "input[name='product[renewal_reward_percentage]']", count: 0

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", renewal_reward_percentage: "10" } }

    assert_nil @product.reload.renewal_reward_percentage
  end
end
