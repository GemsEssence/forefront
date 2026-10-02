require "test_helper"

class Forefront::Dashboard::PaymentsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def won(title)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, status: "won", actual_amount: 30_000)
  end

  test "won leads awaiting payment, and instalments due soon or overdue" do
    won("No payment yet")
    payment = Forefront::Payment.create!(lead: won("On instalments"), total_amount: 30_000)
    payment.installments.create!(amount: 10_000, due_on: 3.days.ago.to_date)
    payment.installments.create!(amount: 10_000, due_on: 3.days.from_now.to_date)
    payment.installments.create!(amount: 10_000, due_on: 30.days.from_now.to_date)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "2", metric(:awaiting_payment)
    assert_equal "1", metric(:instalments_due)
    assert_equal "1", metric(:instalments_overdue)
    assert_match "On instalments", drill(:instalments_overdue).first
  end

  test "the team sees receipts recorded today and in the period" do
    travel_to Time.zone.local(2026, 10, 15, 12)
    payment = Forefront::Payment.create!(lead: won("Paying"), total_amount: 30_000)
    Forefront::Receipt.create!(payment: payment, amount: 5_000, received_on: Date.current, payment_method: "cash", recorded_by: @rep)
    Forefront::Receipt.create!(payment: payment, amount: 2_000, received_on: Date.current.beginning_of_month, payment_method: "cash", recorded_by: @rep)
    sign_in_as(@manager)

    get "/forefront/"

    received = widget("payments")
    assert_equal "₹5,000.00", css_select(received, "[data-metric='receipts_received'][data-period='today']").first.text.squish
    assert_match "₹7,000.00", received.text
    assert_equal 1, drill(:receipts_received, period: "today").size
  end
end
