require "test_helper"

class Forefront::ProductTest < ActiveSupport::TestCase
  test "requires a name" do
    product = Forefront::Product.new
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "has no price of its own" do
    assert_not Forefront::Product.column_names.include?("price")
  end

  test "can be allocated to sales persons, who can then see it in their products" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")

    product.admins << rep

    assert_includes rep.products, product
    assert_includes product.admins, rep
  end

  test "cannot be destroyed while a lead still references it" do
    customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    product = Forefront::Product.create!(name: "Widget")
    Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: admin, source: "website", status: "open", product: product)

    assert_not product.destroy
    assert_includes product.errors[:base], "Cannot delete record because dependent leads exist"
  end
end
