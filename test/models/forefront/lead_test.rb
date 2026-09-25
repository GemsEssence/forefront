require "test_helper"

class Forefront::LeadTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "has a followups association" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open")
    followup = lead.followups.create!(assigned_to: @admin, created_by: @admin, followup_type: "call", status: "pending")

    assert_equal [followup], lead.followups.to_a
  end

  test "new lead defaults to a valid, non-blank status" do
    lead = Forefront::Lead.new(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website")

    assert lead.open?
    assert lead.valid?
  end

  test "needs_followup scope excludes won and lost leads" do
    won = Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @admin, source: "website", status: "won", actual_amount: 100, next_followup_at: 1.day.ago)
    lost = Forefront::Lead.create!(title: "Lost", description: "D", customer: @customer, created_by: @admin, source: "website", status: "lost", next_followup_at: 1.day.ago)
    open_lead = Forefront::Lead.create!(title: "Open", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", next_followup_at: 1.day.ago)

    result = Forefront::Lead.needs_followup

    assert_includes result, open_lead
    assert_not_includes result, won
    assert_not_includes result, lost
  end
end
