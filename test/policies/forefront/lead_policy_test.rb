require "test_helper"

class Forefront::LeadPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @reps_lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open")
    @other_reps_lead = Forefront::Lead.create!(title: "L2", description: "D", customer: @customer, created_by: @other_rep, assigned_to: @other_rep, source: forefront_source, status: "open")
  end

  test "admin's scope includes every lead" do
    resolved = Forefront::LeadPolicy::Scope.new(@admin, Forefront::Lead.all).resolve
    assert_includes resolved, @reps_lead
    assert_includes resolved, @other_reps_lead
  end

  test "manager's scope includes their direct report's leads but not other reps' leads" do
    resolved = Forefront::LeadPolicy::Scope.new(@manager, Forefront::Lead.all).resolve
    assert_includes resolved, @reps_lead
    assert_not_includes resolved, @other_reps_lead
  end

  test "sales person's scope includes only their own leads" do
    resolved = Forefront::LeadPolicy::Scope.new(@rep, Forefront::Lead.all).resolve
    assert_includes resolved, @reps_lead
    assert_not_includes resolved, @other_reps_lead
  end

  test "manager can show and update their direct report's lead" do
    policy = Forefront::LeadPolicy.new(@manager, @reps_lead)
    assert policy.show?
    assert policy.update?
  end

  test "manager cannot show or update another rep's lead" do
    policy = Forefront::LeadPolicy.new(@manager, @other_reps_lead)
    assert_not policy.show?
    assert_not policy.update?
  end

  test "an admin can update any lead, even one they neither created nor are assigned to" do
    policy = Forefront::LeadPolicy.new(@admin, @other_reps_lead)
    assert policy.update?
  end
end
