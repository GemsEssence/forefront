require "test_helper"

class Forefront::TicketTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "has a followups association" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", status: "open")
    followup = ticket.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending", scheduled_for: 1.day.from_now)

    assert_equal [followup], ticket.followups.to_a
  end

  test "destroying a ticket destroys its followups" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", status: "open")
    followup = ticket.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending", scheduled_for: 1.day.from_now)

    ticket.destroy

    assert_raises(ActiveRecord::RecordNotFound) { followup.reload }
  end

  test "new ticket defaults to a valid, non-blank status" do
    ticket = Forefront::Ticket.new(title: "T", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium")

    assert ticket.open?
    assert ticket.valid?
  end

  test "a ticket has no next_followup_at of its own: Followups are the only follow-up" do
    assert_not Forefront::Ticket.column_names.include?("next_followup_at")
    assert_not Forefront::Ticket.respond_to?(:needs_followup)
  end
end
