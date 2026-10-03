require "test_helper"

class Forefront::Dashboard::RevenueTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    # A Payment with Installments only takes Receipts against an Installment,
    # so one-off Receipts go to a Payment without any.
    @one_off_payment = Forefront::Payment.create!(lead: won("Paying once"), total_amount: 30_000)
    @instalment_payment = Forefront::Payment.create!(lead: won("Paying in parts"), total_amount: 30_000)
    @installment = @instalment_payment.installments.create!(amount: 10_000, due_on: Date.current)
  end

  def won(title)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, status: "won", actual_amount: 30_000)
  end

  def receipt(payment, amount, on, installment: nil)
    Forefront::Receipt.create!(payment: payment, installment: installment, amount: amount, received_on: on, payment_method: "cash", recorded_by: @rep)
  end

  test "revenue in the period is split into one-off and instalment, with a monthly trend" do
    receipt(@one_off_payment, 5_000, Date.current)
    receipt(@instalment_payment, 10_000, Date.current, installment: @installment)
    receipt(@one_off_payment, 3_000, Date.current.prev_month)
    sign_in_as(@admin)

    get "/forefront/"

    revenue = widget("revenue")
    assert_equal "₹15,000.00", css_select(revenue, "[data-metric='receipts_received']:not([data-slice])").first.text.squish
    assert_equal "₹5,000.00", css_select(revenue, "[data-metric='receipts_received'][data-slice='one_off']").first.text.squish
    assert_equal "₹10,000.00", css_select(revenue, "[data-metric='receipts_received'][data-slice='instalment']").first.text.squish
    months = css_select(revenue, "[data-trend-month]").map { |bar| bar.text.squish }
    assert_equal 12, months.size
    assert_match "₹3,000.00", months[-2]
    assert_match "₹15,000.00", months[-1]
  end
end
