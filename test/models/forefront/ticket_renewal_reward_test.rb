require "test_helper"

class Forefront::TicketRenewalRewardTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @product = Forefront::Product.create!(name: "Widget", price: 100, renewal_reward_percentage: 10)
    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)
    @lead.update!(status: "won", expires_at: 1.week.from_now.to_date)
    Forefront::Payment.create!(lead: @lead, total_amount: 400, status: "paid", paid_at: Time.current)
  end

  def build_renewal_ticket
    Forefront::Ticket.create!(title: "Renew?", description: "D", customer: @customer, created_by: @admin, category: "plan_expired", priority: "medium", status: "open", product: @product)
  end

  test "no reward while the renewal ticket is still open" do
    ticket = build_renewal_ticket
    assert_equal 0, ticket.renewal_reward_amount
  end

  test "no reward when resolved with a declined outcome" do
    ticket = build_renewal_ticket
    ticket.update!(status: "resolved", renewal_outcome: "declined")
    assert_equal 0, ticket.renewal_reward_amount
  end

  test "a percentage reward of the subscription's original payment once renewed" do
    ticket = build_renewal_ticket
    ticket.update!(status: "resolved", renewal_outcome: "renewed")

    assert_equal 40, ticket.renewal_reward_amount
  end

  test "no reward when the product has no renewal_reward_percentage configured" do
    @product.update!(renewal_reward_percentage: nil)
    ticket = build_renewal_ticket
    ticket.update!(status: "resolved", renewal_outcome: "renewed")

    assert_equal 0, ticket.renewal_reward_amount
  end

  test "no reward when there is no matching subscription for this customer and product" do
    other_product = Forefront::Product.create!(name: "Other", price: 50, renewal_reward_percentage: 10)
    ticket = Forefront::Ticket.create!(title: "Renew?", description: "D", customer: @customer, created_by: @admin, category: "plan_expired", priority: "medium", status: "open", product: other_product)
    ticket.update!(status: "resolved", renewal_outcome: "renewed")

    assert_equal 0, ticket.renewal_reward_amount
  end
end
