require "test_helper"

class Forefront::LeadProductRestrictionTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @allowed_product = Forefront::Product.create!(name: "Allowed")
    @other_product = Forefront::Product.create!(name: "Other")
    @allowed_product.admins << @rep
  end

  test "a sales person can be assigned a lead for a product allocated to them" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @rep, source: forefront_source, status: "open", product: @allowed_product)
    assert lead.valid?
  end

  test "a sales person cannot be assigned a lead for a product not allocated to them" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @rep, source: forefront_source, status: "open", product: @other_product)
    assert_not lead.valid?
    assert_includes lead.errors[:product], "is not assigned to this sales person"
  end

  test "a manager can be assigned a lead for any product" do
    manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: manager, source: forefront_source, status: "open", product: @other_product)
    assert lead.valid?
  end

  test "an admin is never assigned a lead" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @admin, source: forefront_source, status: "open", product: @other_product)
    assert_not lead.valid?
    assert_includes lead.errors[:assigned_to], "can't be an admin"
  end

  test "a lead with no product is still valid" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @rep, source: forefront_source, status: "open")
    assert lead.valid?
  end
end
