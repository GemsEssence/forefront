require "test_helper"

class Forefront::PaymentManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open", product: @product)
  end

  test "a sales person can record a payment and split it into installments, and see the reminder followup" do
    sign_in_as(@rep)
    @lead.update!(status: "won", actual_amount: 100)

    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_match "Record Payment", response.body

    get "/forefront/leads/#{@lead.id}/payment/new"
    assert_response :success

    assert_difference "Forefront::Payment.count", 1 do
      post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: "300" } }
    end
    assert_redirected_to "/forefront/leads/#{@lead.id}"

    assert_difference "Forefront::Installment.count", 1 do
      post "/forefront/leads/#{@lead.id}/payment/installments", params: { installment: { amount: "150", due_on: "2026-06-20" } }
    end
    assert_redirected_to "/forefront/leads/#{@lead.id}"

    installment = Forefront::Installment.order(:created_at).last
    assert_equal 1, installment.followups.count

    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_match "150", response.body

    post "/forefront/leads/#{@lead.id}/payment/receipts",
         params: { receipt: { installment_id: installment.id, amount: "150", received_on: "2026-06-18", payment_method: "upi" } }
    assert_redirected_to "/forefront/leads/#{@lead.id}"
    assert installment.reload.paid?
    assert_equal "completed", installment.followups.first.reload.status
  end

  test "recording a payment for a lead that is not yet won is blocked" do
    sign_in_as(@rep)

    get "/forefront/leads/#{@lead.id}/payment/new"
    assert_redirected_to "/forefront/leads/#{@lead.id}"

    assert_no_difference "Forefront::Payment.count" do
      post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: "300" } }
    end
  end

  test "an unrelated sales person cannot record a payment on someone else's lead" do
    other_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @lead.update!(status: "won", actual_amount: 100)
    sign_in_as(other_rep)

    get "/forefront/leads/#{@lead.id}/payment/new"
    assert_redirected_to "/forefront/"
  end
end
