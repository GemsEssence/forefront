require "test_helper"

class Forefront::AdminPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @other_manager = Forefront::Admin.create!(name: "Other Manager", email: "othermanager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @other_manager)
  end

  test "admin can manage staff, sales person cannot" do
    assert Forefront::AdminPolicy.new(@admin, Forefront::Admin.new).index?
    assert_not Forefront::AdminPolicy.new(@rep, Forefront::Admin.new).index?
  end

  test "manager can manage staff" do
    assert Forefront::AdminPolicy.new(@manager, Forefront::Admin.new).index?
  end

  test "admin's scope includes every staff member" do
    resolved = Forefront::AdminPolicy::Scope.new(@admin, Forefront::Admin.all).resolve
    assert_includes resolved, @rep
    assert_includes resolved, @other_rep
    assert_includes resolved, @manager
  end

  test "manager's scope includes only their own direct reports" do
    resolved = Forefront::AdminPolicy::Scope.new(@manager, Forefront::Admin.all).resolve
    assert_includes resolved, @rep
    assert_not_includes resolved, @other_rep
    assert_not_includes resolved, @manager
  end

  test "sales person's scope is empty" do
    resolved = Forefront::AdminPolicy::Scope.new(@rep, Forefront::Admin.all).resolve
    assert_empty resolved
  end

  test "admin can create a manager or another admin" do
    new_manager = Forefront::Admin.new(role: "manager")
    new_admin = Forefront::Admin.new(role: "admin")
    assert Forefront::AdminPolicy.new(@admin, new_manager).create?
    assert Forefront::AdminPolicy.new(@admin, new_admin).create?
  end

  test "manager can only create a sales person reporting to themselves" do
    valid = Forefront::Admin.new(role: "sales_person", manager_id: @manager.id)
    wrong_role = Forefront::Admin.new(role: "manager", manager_id: @manager.id)
    wrong_manager = Forefront::Admin.new(role: "sales_person", manager_id: @other_manager.id)

    assert Forefront::AdminPolicy.new(@manager, valid).create?
    assert_not Forefront::AdminPolicy.new(@manager, wrong_role).create?
    assert_not Forefront::AdminPolicy.new(@manager, wrong_manager).create?
  end

  test "manager can edit their own direct report but not another manager's report" do
    assert Forefront::AdminPolicy.new(@manager, @rep).edit?
    assert_not Forefront::AdminPolicy.new(@manager, @other_rep).edit?
  end

  test "manager cannot edit another manager or an admin" do
    assert_not Forefront::AdminPolicy.new(@manager, @other_manager).edit?
    assert_not Forefront::AdminPolicy.new(@manager, @admin).edit?
  end

  test "admin can edit anyone" do
    assert Forefront::AdminPolicy.new(@admin, @rep).edit?
    assert Forefront::AdminPolicy.new(@admin, @manager).edit?
  end
end
