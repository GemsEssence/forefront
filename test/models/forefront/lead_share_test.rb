require "test_helper"

class Forefront::LeadShareTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @alice = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @bob = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @carol = Forefront::Admin.create!(name: "Carol", email: "carol-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @alice, source: forefront_source, status: "open")
    Forefront::AssignmentOperations::Create.new(assignable: @lead, params: { to_user_id: @alice.id, from_user_id: nil }, current_admin: @admin).call
    Forefront::AssignmentOperations::Create.new(assignable: @lead, params: { to_user_id: @bob.id }, current_admin: @admin).call
    @lead.reload
  end

  test "past_assignees returns everyone the lead was ever assigned to" do
    assert_equal [ @alice, @bob ].sort_by(&:id), @lead.past_assignees.sort_by(&:id)
  end

  test "a lead share must include every past assignee, no more, no fewer" do
    missing_someone = Forefront::LeadShare.new(lead: @lead, recorded_by: @admin)
    missing_someone.lead_share_participants.build(admin: @alice, percentage: 100)

    assert_not missing_someone.valid?
    assert_includes missing_someone.errors[:base], "must include every sales person the lead was ever assigned to, and no one else"

    includes_a_stranger = Forefront::LeadShare.new(lead: @lead, recorded_by: @admin)
    includes_a_stranger.lead_share_participants.build(admin: @alice, percentage: 50)
    includes_a_stranger.lead_share_participants.build(admin: @bob, percentage: 25)
    includes_a_stranger.lead_share_participants.build(admin: @carol, percentage: 25)

    assert_not includes_a_stranger.valid?
    assert_includes includes_a_stranger.errors[:base], "must include every sales person the lead was ever assigned to, and no one else"
  end

  test "percentages across participants must sum to exactly 100" do
    share = Forefront::LeadShare.new(lead: @lead, recorded_by: @admin)
    share.lead_share_participants.build(admin: @alice, percentage: 50)
    share.lead_share_participants.build(admin: @bob, percentage: 40)

    assert_not share.valid?
    assert_includes share.errors[:base], "percentages must add up to 100"
  end

  test "a valid share with the full set of past assignees summing to 100 saves" do
    share = Forefront::LeadShare.new(lead: @lead, recorded_by: @admin)
    share.lead_share_participants.build(admin: @alice, percentage: 60)
    share.lead_share_participants.build(admin: @bob, percentage: 40)

    assert share.save
  end

  test "share_fraction_for returns 1.0 for the sole assignee of an unshared lead, 0 for anyone else" do
    assert_equal 1.0, @lead.share_fraction_for(@bob.id)
    assert_equal 0, @lead.share_fraction_for(@alice.id)
  end

  test "share_fraction_for returns each participant's own percentage once shared" do
    share = Forefront::LeadShare.new(lead: @lead, recorded_by: @admin)
    share.lead_share_participants.build(admin: @alice, percentage: 30)
    share.lead_share_participants.build(admin: @bob, percentage: 70)
    share.save!

    assert_equal 0.3, @lead.reload.share_fraction_for(@alice.id)
    assert_equal 0.7, @lead.reload.share_fraction_for(@bob.id)
    assert_equal 0, @lead.reload.share_fraction_for(@carol.id)
  end
end
