require "test_helper"

class Forefront::PaymentTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @product = Forefront::Product.create!(name: "Widget", price: 100)
    @won_lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "won", product: @product)
    @open_lead = Forefront::Lead.create!(title: "L2", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open")
  end

  test "can only be created for a won lead" do
    payment = Forefront::Payment.new(lead: @open_lead, total_amount: 100)
    assert_not payment.valid?
    assert_includes payment.errors[:lead], "must be won before a payment can be recorded"
  end

  test "a lead can only have one payment" do
    Forefront::Payment.create!(lead: @won_lead, total_amount: 100)
    duplicate = Forefront::Payment.new(lead: @won_lead, total_amount: 100)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:lead_id], "has already been taken"
  end

  test "fully_paid? reflects status directly when there are no installments" do
    payment = Forefront::Payment.create!(lead: @won_lead, total_amount: 100)
    assert_not payment.fully_paid?

    payment.update!(status: "paid", paid_at: Time.current)
    assert payment.fully_paid?
  end

  test "fully_paid? is derived from installments once any exist, ignoring its own status" do
    payment = Forefront::Payment.create!(lead: @won_lead, total_amount: 100, status: "paid")
    installment = payment.installments.create!(amount: 100, due_on: Date.tomorrow)

    assert_not payment.fully_paid?

    installment.update!(status: "paid", paid_at: Time.current)
    assert payment.fully_paid?
  end
end
