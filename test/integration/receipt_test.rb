require "test_helper"

class Forefront::ReceiptTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, status: "won", actual_amount: 20_000)
    @payment = Forefront::Payment.create!(lead: @lead, total_amount: 20_000)
    sign_in_as(@rep)
  end

  def receive(amount, installment: nil, **extra)
    post "/forefront/leads/#{@lead.id}/payment/receipts",
         params: { receipt: { amount: amount, installment_id: installment&.id, received_on: "2026-10-05", payment_method: "upi", reference: "UPI-123" }.merge(extra) }
  end

  test "partial receipts pay an installment once they add up to it" do
    first = @payment.installments.create!(amount: 10_000, due_on: "2026-10-10")
    @payment.installments.create!(amount: 10_000, due_on: "2026-11-10")

    receive("4000", installment: first)
    assert first.reload.pending?

    receive("6000", installment: first)
    assert first.reload.paid?
    assert_not @payment.reload.paid?
  end

  test "the payment is paid once every installment is" do
    installments = [ 10_000, 10_000 ].each_with_index.map { |amount, i| @payment.installments.create!(amount: amount, due_on: Date.new(2026, 10 + i, 10)) }

    installments.each { |installment| receive("10000", installment: installment) }

    assert @payment.reload.paid?
    assert @payment.fully_paid?
  end

  test "a payment without installments takes receipts directly" do
    receive("15000")
    assert @payment.reload.pending?

    receive("5000")
    assert @payment.reload.paid?
  end

  test "a receipt can't take more than is still owed" do
    receive("15000")
    receive("6000")

    assert_match "Amount is more than the 5,000.00 still owed", flash[:alert]
    assert_equal 1, @payment.receipts.count
  end

  test "once a payment has installments, a receipt must say which one it's for" do
    @payment.installments.create!(amount: 20_000, due_on: "2026-10-10")

    receive("5000")

    assert_match "Installment must be chosen", flash[:alert]
  end

  test "a receipt needs its date and method" do
    receive("5000", received_on: "", payment_method: "")

    assert_match "Received on can't be blank", flash[:alert]
    assert_match "Payment method can't be blank", flash[:alert]
  end

  test "the lead page lists receipts and what's still owed" do
    receive("15000")

    get "/forefront/leads/#{@lead.id}"
    assert_select "#receipts li", text: /5 Oct 2026.*15,000\.00.*UPI · UPI-123/m
    assert_match "5,000.00 still owed", response.body
    assert_select "form[action='/forefront/leads/#{@lead.id}/payment/receipts']"
  end

  test "recording a receipt is audited" do
    receive("15000")

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    delete "/forefront/admins/sign_out"
    sign_in_as(admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*recorded receipt.*Lead.*Big Deal.*Amount: — → 15000/m
  end
end
