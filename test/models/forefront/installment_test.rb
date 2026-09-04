require "test_helper"

class Forefront::InstallmentTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget", price: 300)
    @product.admins << @rep
    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @rep, source: "website", status: "won", product: @product)
    @payment = Forefront::Payment.create!(lead: @lead, total_amount: 300)
  end

  test "installments on the same payment cannot exceed the payment total" do
    @payment.installments.create!(amount: 200, due_on: Date.tomorrow)
    over_the_top = @payment.installments.build(amount: 150, due_on: 1.month.from_now.to_date)

    assert_not over_the_top.valid?
    assert_includes over_the_top.errors[:amount], "would bring the total installments above the payment's total_amount"
  end

  test "creating an installment automatically schedules a reminder followup for the lead's assignee" do
    installment = @payment.installments.create!(amount: 150, due_on: Date.new(2026, 6, 20))

    followup = installment.followups.sole
    assert_equal @rep, followup.assigned_to
    assert_equal Date.new(2026, 6, 17), followup.scheduled_for.to_date
    assert_equal "pending", followup.status
  end

  test "marking an installment paid completes its pending reminder followups" do
    installment = @payment.installments.create!(amount: 150, due_on: Date.tomorrow)
    followup = installment.followups.sole

    installment.update!(status: "paid", paid_at: Time.current)

    assert_equal "completed", followup.reload.status
  end
end
