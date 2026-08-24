require "test_helper"

class Forefront::ProductManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "an admin can create a product and allocate it to a sales person" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    sign_in_as(admin)

    get "/forefront/products"
    assert_response :success

    get "/forefront/products/new"
    assert_response :success

    assert_difference "Forefront::Product.count", 1 do
      post "/forefront/products", params: { product: { name: "Widget", description: "A thing", price: "49.99", admin_ids: [ rep.id.to_s ] } }
    end
    assert_redirected_to "/forefront/products"

    product = Forefront::Product.order(:created_at).last
    assert_includes product.admins, rep
  end

  test "a sales person can view but not create products" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    sign_in_as(rep)

    get "/forefront/products"
    assert_response :success

    get "/forefront/products/new"
    assert_redirected_to "/forefront/"
  end

  test "a sales person can only pick from products allocated to them when creating a lead" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    allowed = Forefront::Product.create!(name: "Allowed", price: 100)
    forbidden = Forefront::Product.create!(name: "Forbidden Gadget", price: 200)
    allowed.admins << rep
    sign_in_as(rep)

    get "/forefront/leads/new"
    assert_response :success
    assert_match "Allowed", response.body
    assert_no_match "Forbidden Gadget", response.body

    post "/forefront/leads", params: { lead: { title: "L", description: "D", customer_id: customer.id, source: "website", product_id: forbidden.id } }
    assert_response :unprocessable_entity
    assert_equal 0, Forefront::Lead.where(title: "L").count
  end
end
