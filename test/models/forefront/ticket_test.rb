require "test_helper"

class Forefront::TicketTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "has a followups association" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "open")
    followup = ticket.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending")

    assert_equal [followup], ticket.followups.to_a
  end

  test "destroying a ticket destroys its followups" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "open")
    followup = ticket.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending")

    ticket.destroy

    assert_raises(ActiveRecord::RecordNotFound) { followup.reload }
  end

  test "new ticket defaults to a valid, non-blank status" do
    ticket = Forefront::Ticket.new(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium")

    assert ticket.open?
    assert ticket.valid?
  end

  test "needs_followup scope excludes resolved and closed tickets" do
    resolved = Forefront::Ticket.create!(title: "Resolved", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "resolved", next_followup_at: 1.day.ago)
    closed = Forefront::Ticket.create!(title: "Closed", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "closed", next_followup_at: 1.day.ago)
    open_ticket = Forefront::Ticket.create!(title: "Open", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "open", next_followup_at: 1.day.ago)

    result = Forefront::Ticket.needs_followup

    assert_includes result, open_ticket
    assert_not_includes result, resolved
    assert_not_includes result, closed
  end
end
