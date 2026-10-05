require "test_helper"

class Forefront::FollowupTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", status: "open")
  end

  test "loads without raising (enum syntax is valid)" do
    assert Forefront::Followup.followup_types.present?
    assert Forefront::Followup.statuses.present?
  end

  test "assigned_to is required" do
    followup = Forefront::Followup.new(followupable: @ticket, created_by: @admin, followup_type: "call", status: "pending")

    assert_not followup.valid?
    assert_includes followup.errors[:assigned_to], "can't be blank"
  end

  test "created_by is required" do
    followup = Forefront::Followup.new(followupable: @ticket, assigned_to: @admin, followup_type: "call", status: "pending")

    assert_not followup.valid?
    assert_includes followup.errors[:created_by], "must exist"
  end

  test "type and scheduled time are required" do
    followup = Forefront::Followup.new(followupable: @ticket, assigned_to: @admin, created_by: @admin, followup_type: "", scheduled_for: "")

    assert_not followup.valid?
    assert_includes followup.errors[:followup_type], "can't be blank"
    assert_includes followup.errors[:scheduled_for], "can't be blank"
  end

  test "a blank form on an assigned ticket reports errors instead of hitting the database" do
    @ticket.update!(assigned_to: @admin)

    result = Forefront::FollowupOperations::Create.new(
      followupable: @ticket,
      params: ActionController::Parameters.new(followup_type: "", scheduled_for: "", assigned_to_id: "", outcome: ""),
      current_admin: @admin
    ).call

    assert_not result[:success]
    assert_includes result[:errors], "Followup type can't be blank"
    assert_includes result[:errors], "Scheduled for can't be blank"
  end

  test "with no assignee given and none on the ticket, the error says who to pick" do
    result = Forefront::FollowupOperations::Create.new(
      followupable: @ticket,
      params: ActionController::Parameters.new(followup_type: "call", scheduled_for: 1.day.from_now.to_s),
      current_admin: @admin
    ).call

    assert_not result[:success]
    assert_includes result[:errors], "Assigned to can't be blank"
  end
end
