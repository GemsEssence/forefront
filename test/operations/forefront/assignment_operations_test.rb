require "test_helper"

class Forefront::AssignmentOperationsTest < ActiveSupport::TestCase
  setup do
    @admin1 = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @admin2 = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin1, category: "new_app_demo", priority: "medium", status: "open")
  end

  test "the first-ever assignment succeeds and records no from_user" do
    result = Forefront::AssignmentOperations::Create.new(
      assignable: @ticket,
      params: { to_user_id: @admin1.id },
      current_admin: @admin1
    ).call

    assert result[:success]
    assignment = @ticket.assignments.last
    assert_nil assignment.from_user_id
    assert_equal @admin1.id, assignment.to_user_id
    assert_equal @admin1.id, assignment.changed_by_id
  end

  test "reassigning records the previous assignee as from_user" do
    @ticket.update!(assigned_to: @admin1)

    result = Forefront::AssignmentOperations::Create.new(
      assignable: @ticket,
      params: { to_user_id: @admin2.id },
      current_admin: @admin1
    ).call

    assert result[:success]
    assignment = @ticket.assignments.last
    assert_equal @admin1.id, assignment.from_user_id
    assert_equal @admin2.id, assignment.to_user_id
  end
end
