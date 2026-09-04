require "test_helper"

class Forefront::LeadShareOperationsTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @alice = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @bob = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @alice, source: "website", status: "open")
    Forefront::AssignmentOperations::Create.new(assignable: @lead, params: { to_user_id: @alice.id, from_user_id: nil }, current_admin: @admin).call
    Forefront::AssignmentOperations::Create.new(assignable: @lead, params: { to_user_id: @bob.id }, current_admin: @admin).call
    @lead.reload
  end

  test "records a new share with the given percentages" do
    result = Forefront::LeadShareOperations::Save.new(
      lead: @lead,
      params: { percentages: { @alice.id.to_s => "30", @bob.id.to_s => "70" } },
      current_admin: @admin
    ).call

    assert result[:success]
    assert_equal @admin, @lead.reload.lead_share.recorded_by
    assert_equal 0.3, @lead.share_fraction_for(@alice.id)
    assert_equal 0.7, @lead.share_fraction_for(@bob.id)
  end

  test "an invalid split (not summing to 100) is rejected without leaving a partial record" do
    result = Forefront::LeadShareOperations::Save.new(
      lead: @lead,
      params: { percentages: { @alice.id.to_s => "30", @bob.id.to_s => "30" } },
      current_admin: @admin
    ).call

    assert_not result[:success]
    assert_nil @lead.reload.lead_share
  end

  test "saving again replaces the previous split rather than adding to it" do
    Forefront::LeadShareOperations::Save.new(
      lead: @lead, params: { percentages: { @alice.id.to_s => "50", @bob.id.to_s => "50" } }, current_admin: @admin
    ).call

    result = Forefront::LeadShareOperations::Save.new(
      lead: @lead, params: { percentages: { @alice.id.to_s => "20", @bob.id.to_s => "80" } }, current_admin: @admin
    ).call

    assert result[:success]
    assert_equal 2, @lead.reload.lead_share.lead_share_participants.count
    assert_equal 0.2, @lead.share_fraction_for(@alice.id)
    assert_equal 0.8, @lead.share_fraction_for(@bob.id)
  end
end
