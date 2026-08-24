require "test_helper"

class Forefront::FollowupPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @rep, category: "issue", priority: "medium", status: "open")
    @followup = Forefront::Followup.create!(followupable: @ticket, assigned_to: @rep, created_by: @rep, followup_type: "call", status: "pending", scheduled_for: 1.day.from_now)
  end

  test "any signed-in admin can create a followup" do
    assert Forefront::FollowupPolicy.new(@rep, @followup).create?
  end

  test "super admin can update any followup" do
    assert Forefront::FollowupPolicy.new(@admin, @followup).update?
  end

  test "an unrelated sales person cannot update someone else's followup" do
    assert_not Forefront::FollowupPolicy.new(@other_rep, @followup).update?
  end

  test "scope resolves to only the current admin's followups when not a super admin" do
    resolved = Forefront::FollowupPolicy::Scope.new(@rep, Forefront::Followup.all).resolve
    assert_includes resolved, @followup

    resolved_for_other = Forefront::FollowupPolicy::Scope.new(@other_rep, Forefront::Followup.all).resolve
    assert_not_includes resolved_for_other, @followup
  end
end
