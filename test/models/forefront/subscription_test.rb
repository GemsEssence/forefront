require "test_helper"

class Forefront::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @product = Forefront::Product.create!(name: "Widget")
  end

  test "a subscription is created automatically the moment a Lead with a product is won" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)

    assert_nil lead.subscription

    lead.update!(status: "won", expires_at: Date.new(2027, 1, 1))

    subscription = lead.reload.subscription
    assert_not_nil subscription
    assert_equal @customer, subscription.customer
    assert_equal @product, subscription.product
    assert_equal Date.new(2027, 1, 1), subscription.expires_at
  end

  test "no subscription is created for a Lead won without a product" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open")

    lead.update!(status: "won")

    assert_nil lead.reload.subscription
  end

  test "winning a lead without an expires_at does not create a subscription yet" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)

    lead.update!(status: "won")

    assert_nil lead.reload.subscription
  end

  test "later setting expires_at on an already-won lead creates the subscription" do
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)
    lead.update!(status: "won")
    assert_nil lead.reload.subscription

    lead.update!(expires_at: Date.new(2027, 6, 1))

    assert_equal Date.new(2027, 6, 1), lead.reload.subscription.expires_at
  end

  test "expired? reflects whether expires_at has passed" do
    subscription = Forefront::Subscription.new(expires_at: Date.yesterday)
    assert subscription.expired?

    subscription.expires_at = Date.tomorrow
    assert_not subscription.expired?
  end
end
