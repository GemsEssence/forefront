require "test_helper"

class Forefront::ProductApiKeyTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @product = Forefront::Product.create!(name: "Widget")
  end

  def generate_key
    post "/forefront/products/#{@product.id}/api_key"
    css_select("[data-api-key]").first&.text&.strip
  end

  test "an admin generates a product's key and sees it once" do
    sign_in_as(@admin)

    key = generate_key

    assert_response :success
    assert key.present?
    assert_equal @product, Forefront::Product.find_by_api_key(key)

    get "/forefront/products/#{@product.id}/edit"
    assert_no_match key, response.body
    assert_select "p", text: /Key ending …#{key.last(4)}/
  end

  test "regenerating replaces the old key at once" do
    sign_in_as(@admin)
    old_key = generate_key

    new_key = generate_key

    assert_nil Forefront::Product.find_by_api_key(old_key)
    assert_equal @product, Forefront::Product.find_by_api_key(new_key)
  end

  test "an unknown or blank key finds no product" do
    assert_nil Forefront::Product.find_by_api_key("ff_not-a-real-key")
    assert_nil Forefront::Product.find_by_api_key("")
    assert_nil Forefront::Product.find_by_api_key(nil)
  end

  test "generating a key is audited, without the key" do
    sign_in_as(@admin)
    key = generate_key

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*generated api key.*Product.*Widget/m
    assert_no_match key, response.body
  end

  test "a manager can't generate a key" do
    manager = Forefront::Admin.create!(name: "Mona", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    post "/forefront/products/#{@product.id}/api_key"

    assert_redirected_to "/forefront/"
    assert_nil @product.reload.api_key_digest
  end
end
