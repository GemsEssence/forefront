require "test_helper"

class Forefront::LeadReclaimRewardTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @product = Forefront::Product.create!(name: "Widget", reclaim_reward_percentage: 20)

    @old_lead = Forefront::Lead.create!(title: "Old", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)
    @old_lead.update!(status: "won", expires_at: 4.months.ago.to_date)
  end

  test "a new lead is not a reclaim before the old subscription is even expired" do
    @old_lead.update!(expires_at: 1.month.from_now.to_date)
    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)

    assert_not new_lead.reclaim?
  end

  test "a new lead is not a reclaim until the cooldown period has passed" do
    @old_lead.update!(expires_at: 1.month.ago.to_date)
    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)

    assert_not new_lead.reclaim?
  end

  test "a new lead for the same customer and product is a reclaim once the cooldown has passed" do
    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)

    assert new_lead.reclaim?
  end

  test "reclaim_reward_amount pays a percentage of the reclaimed lead's own payment once won and paid" do
    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)
    assert_equal 0, new_lead.reclaim_reward_amount

    new_lead.update!(status: "won")
    Forefront::Payment.create!(lead: new_lead, total_amount: 300, status: "paid", paid_at: Time.current)

    assert_equal 60, new_lead.reload.reclaim_reward_amount
  end

  test "no reclaim reward when the product has no reclaim_reward_percentage configured" do
    @product.update!(reclaim_reward_percentage: nil)
    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, source: "website", status: "won", product: @product)
    Forefront::Payment.create!(lead: new_lead, total_amount: 300, status: "paid", paid_at: Time.current)

    assert_equal 0, new_lead.reload.reclaim_reward_amount
  end

  test "reclaim_reward_amount_for splits the total reward according to the lead's share" do
    alice = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    bob = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product.admins << alice << bob

    new_lead = Forefront::Lead.create!(title: "New", description: "D", customer: @customer, created_by: @admin, assigned_to: alice, source: "website", status: "open", product: @product)
    Forefront::AssignmentOperations::Create.new(assignable: new_lead, params: { to_user_id: alice.id, from_user_id: nil }, current_admin: @admin).call
    Forefront::AssignmentOperations::Create.new(assignable: new_lead, params: { to_user_id: bob.id }, current_admin: @admin).call
    new_lead.update!(status: "won")
    Forefront::Payment.create!(lead: new_lead, total_amount: 300, status: "paid", paid_at: Time.current)

    assert_equal 60, new_lead.reload.reclaim_reward_amount_for(bob.id)

    share = Forefront::LeadShare.new(lead: new_lead, recorded_by: @admin)
    share.lead_share_participants.build(admin: alice, percentage: 25)
    share.lead_share_participants.build(admin: bob, percentage: 75)
    share.save!

    assert_equal 15, new_lead.reload.reclaim_reward_amount_for(alice.id)
    assert_equal 45, new_lead.reload.reclaim_reward_amount_for(bob.id)
  end
end
