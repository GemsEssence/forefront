require "test_helper"

class Forefront::ProductAllocationTest < ActiveSupport::TestCase
  test "cannot allocate the same product to the same admin twice" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    Forefront::ProductAllocation.create!(product: product, admin: rep)

    duplicate = Forefront::ProductAllocation.new(product: product, admin: rep)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been allocated to this admin"
  end
end
