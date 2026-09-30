require "test_helper"

class Forefront::ProductOperationsTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
  end

  test "create builds a product and allocates it to the given sales persons" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    result = Forefront::ProductOperations::Create.new(
      params: { name: "Widget", description: "A thing", admin_ids: [ rep.id.to_s ] },
      current_admin: @admin
    ).call

    assert result[:success]
    assert_equal [ rep ], result[:product].admins
  end

  test "update replaces the set of allocated sales persons" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    product.admins << rep

    result = Forefront::ProductOperations::Update.new(
      product: product,
      params: { name: "Widget", admin_ids: [ other_rep.id.to_s ] },
      current_admin: @admin
    ).call

    assert result[:success]
    assert_equal [ other_rep ], result[:product].reload.admins
  end

  test "update with no admin_ids clears all allocations" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    product = Forefront::Product.create!(name: "Widget")
    product.admins << rep

    result = Forefront::ProductOperations::Update.new(
      product: product,
      params: { name: "Widget" },
      current_admin: @admin
    ).call

    assert result[:success]
    assert_empty product.reload.admins
  end
end
