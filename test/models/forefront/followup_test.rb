require "test_helper"

class Forefront::FollowupTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium", status: "open")
  end

  test "loads without raising (enum syntax is valid)" do
    assert Forefront::Followup.followup_types.present?
    assert Forefront::Followup.statuses.present?
  end

  test "assigned_to is required" do
    followup = Forefront::Followup.new(followupable: @ticket, created_by: @admin, followup_type: "call", status: "pending")

    assert_not followup.valid?
    assert_includes followup.errors[:assigned_to], "must exist"
  end

  test "created_by is required" do
    followup = Forefront::Followup.new(followupable: @ticket, assigned_to: @admin, followup_type: "call", status: "pending")

    assert_not followup.valid?
    assert_includes followup.errors[:created_by], "must exist"
  end
end
