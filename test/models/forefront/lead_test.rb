require "test_helper"

class Forefront::LeadTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "has a followups association" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "open")
    followup = lead.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending", scheduled_for: 1.day.from_now)

    assert_equal [followup], lead.followups.to_a
  end

  test "new lead defaults to a valid, non-blank status" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, source: forefront_source)

    assert lead.open?
    assert lead.valid?
  end

  test "a lead has no next_followup_at of its own: Followups are the only follow-up" do
    assert_not Forefront::Lead.column_names.include?("next_followup_at")
    assert_not Forefront::Lead.respond_to?(:needs_followup)
  end
end
