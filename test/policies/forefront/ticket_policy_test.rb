require "test_helper"

class Forefront::TicketPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Other Rep", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @reps_ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, category: "issue", priority: "medium", status: "open")
    @other_reps_ticket = Forefront::Ticket.create!(title: "T2", description: "D", customer: @customer, created_by: @other_rep, assigned_to: @other_rep, category: "issue", priority: "medium", status: "open")
  end

  test "admin's scope includes every ticket" do
    resolved = Forefront::TicketPolicy::Scope.new(@admin, Forefront::Ticket.all).resolve
    assert_includes resolved, @reps_ticket
    assert_includes resolved, @other_reps_ticket
  end

  test "manager's scope includes their direct report's tickets but not other reps' tickets" do
    resolved = Forefront::TicketPolicy::Scope.new(@manager, Forefront::Ticket.all).resolve
    assert_includes resolved, @reps_ticket
    assert_not_includes resolved, @other_reps_ticket
  end

  test "sales person's scope includes only their own tickets" do
    resolved = Forefront::TicketPolicy::Scope.new(@rep, Forefront::Ticket.all).resolve
    assert_includes resolved, @reps_ticket
    assert_not_includes resolved, @other_reps_ticket
  end

  test "manager can show and update their direct report's ticket" do
    policy = Forefront::TicketPolicy.new(@manager, @reps_ticket)
    assert policy.show?
    assert policy.update?
  end

  test "manager cannot show or update another rep's ticket" do
    policy = Forefront::TicketPolicy.new(@manager, @other_reps_ticket)
    assert_not policy.show?
    assert_not policy.update?
  end

  test "an admin can update any ticket, even one they neither created nor are assigned to" do
    policy = Forefront::TicketPolicy.new(@admin, @other_reps_ticket)
    assert policy.update?
  end
end
