require "test_helper"

class Forefront::TargetPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget", price: 100)
    @reps_target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 1))
    @other_reps_target = Forefront::Target.create!(admin: @other_rep, product: @product, metric: "amount", goal_value: 1000, period: "monthly", starts_on: Date.new(2026, 3, 1))
  end

  test "admin's scope includes every target" do
    resolved = Forefront::TargetPolicy::Scope.new(@admin, Forefront::Target.all).resolve
    assert_includes resolved, @reps_target
    assert_includes resolved, @other_reps_target
  end

  test "manager's scope includes only their direct reports' targets" do
    resolved = Forefront::TargetPolicy::Scope.new(@manager, Forefront::Target.all).resolve
    assert_includes resolved, @reps_target
    assert_not_includes resolved, @other_reps_target
  end

  test "sales person's scope includes only their own targets" do
    resolved = Forefront::TargetPolicy::Scope.new(@rep, Forefront::Target.all).resolve
    assert_includes resolved, @reps_target
    assert_not_includes resolved, @other_reps_target
  end

  test "only admin or manager can create targets, and a manager can only target their own report" do
    for_own_report = Forefront::Target.new(admin: @rep, product: @product)
    for_others_report = Forefront::Target.new(admin: @other_rep, product: @product)

    assert Forefront::TargetPolicy.new(@admin, for_others_report).create?
    assert Forefront::TargetPolicy.new(@manager, for_own_report).create?
    assert_not Forefront::TargetPolicy.new(@manager, for_others_report).create?
    assert_not Forefront::TargetPolicy.new(@rep, for_own_report).create?
  end
end
