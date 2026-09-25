require "test_helper"

class Forefront::RenewalAndReclaimTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @product = Forefront::Product.create!(name: "Widget", renewal_reward_percentage: 10, reclaim_reward_percentage: 20)
    @lead = Forefront::Lead.create!(title: "Original", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open", product: @product)
    sign_in_as(@admin)
  end

  test "winning a lead and setting its expiry creates a subscription, visible via the edit form" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { status: "won", actual_amount: 100 } }
    get "/forefront/leads/#{@lead.id}/edit"
    assert_match "Subscription Expires", response.body

    patch "/forefront/leads/#{@lead.id}", params: { lead: { expires_at: "2027-01-01" } }
    assert_equal Date.new(2027, 1, 1), @lead.reload.subscription.expires_at
  end

  test "a renewal ticket resolved as renewed shows a reward on the ticket page" do
    @lead.update!(status: "won", actual_amount: 100, expires_at: 1.week.from_now.to_date)
    Forefront::Payment.create!(lead: @lead, total_amount: 400, status: "paid", paid_at: Time.current)

    post "/forefront/tickets", params: { ticket: {
      title: "Please renew", description: "D", customer_id: @customer.id, category: "plan_expired", priority: "medium", product_id: @product.id
    } }
    ticket = Forefront::Ticket.order(:created_at).last
    assert_redirected_to "/forefront/tickets/#{ticket.id}"

    patch "/forefront/tickets/#{ticket.id}", params: { ticket: { status: "resolved", renewal_outcome: "renewed" } }

    get "/forefront/tickets/#{ticket.id}"
    assert_response :success
    assert_match "Reward: ₹40.00", response.body
  end

  test "a new lead for a customer whose subscription lapsed 3+ months ago is flagged as a reclaim and rewarded once won and paid" do
    @lead.update!(status: "won", actual_amount: 100, expires_at: 4.months.ago.to_date)

    post "/forefront/leads", params: { lead: { title: "Win them back", description: "D", customer_id: @customer.id, source: "website", product_id: @product.id } }
    new_lead = Forefront::Lead.order(:created_at).last
    assert_redirected_to "/forefront/leads/#{new_lead.id}"

    get "/forefront/leads/#{new_lead.id}"
    assert_match "Reclaim", response.body

    patch "/forefront/leads/#{new_lead.id}", params: { lead: { status: "won", actual_amount: 100 } }
    post "/forefront/leads/#{new_lead.id}/payment", params: { payment: { total_amount: "500" } }

    get "/forefront/leads/#{new_lead.id}"
    assert_match "Reward: ₹100.00", response.body
  end
end
