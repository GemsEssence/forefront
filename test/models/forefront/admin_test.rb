require "test_helper"

class Forefront::AdminTest < ActiveSupport::TestCase
  test "defaults to the sales_person role" do
    admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")

    assert admin.sales_person?
  end

  test "super_admin? reflects the admin role" do
    admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sales_person = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    assert admin.super_admin?
    assert_not sales_person.super_admin?
  end

  test "a sales person can have a manager, and the manager sees them as a direct report" do
    manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sales_person = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: manager)

    assert_equal [ sales_person.id ], manager.direct_report_ids
  end

  test "an admin cannot be set as their own manager" do
    admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    admin.manager_id = admin.id

    assert_not admin.valid?
    assert_includes admin.errors[:manager], "can't be yourself"
  end
end
