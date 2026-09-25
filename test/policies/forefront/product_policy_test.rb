require "test_helper"

class Forefront::ProductPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
  end

  test "anyone signed in can view products" do
    assert Forefront::ProductPolicy.new(@rep, @product).index?
    assert Forefront::ProductPolicy.new(@rep, @product).show?
  end

  test "only admin or manager can create or edit products" do
    assert Forefront::ProductPolicy.new(@admin, @product).create?
    assert Forefront::ProductPolicy.new(@manager, @product).create?
    assert_not Forefront::ProductPolicy.new(@rep, @product).create?

    assert Forefront::ProductPolicy.new(@admin, @product).edit?
    assert_not Forefront::ProductPolicy.new(@rep, @product).edit?
  end
end
