require "test_helper"

class Forefront::AssignmentTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "open")
  end

  test "from_user is optional, since a first-ever assignment has no previous owner" do
    assignment = Forefront::Assignment.new(assignable: @ticket, to_user: @admin, changed_by: @admin)

    assert assignment.valid?
  end

  test "changed_by is required" do
    assignment = Forefront::Assignment.new(assignable: @ticket, to_user: @admin)

    assert_not assignment.valid?
    assert_includes assignment.errors[:changed_by], "must exist"
  end
end
