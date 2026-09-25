require "test_helper"

class Forefront::CurrencyHelperTest < ActionView::TestCase
  include Forefront::CurrencyHelper

  teardown { Forefront.currency = "INR" }

  test "defaults to Indian rupees with lakh/crore grouping" do
    assert_equal "INR", Forefront.currency
    assert_equal "₹1,23,45,678.50", format_money(12_345_678.5)
    assert_equal "₹500.00", format_money(500)
    assert_equal "₹", currency_symbol
  end

  test "formats other common currencies the way they're usually written" do
    Forefront.currency = "USD"
    assert_equal "$1,234,567.50", format_money(1_234_567.5)

    Forefront.currency = "eur"
    assert_equal "1.234,50 €", format_money(1234.5)

    Forefront.currency = "GBP"
    assert_equal "£1,234.50", format_money(1234.5)
  end

  test "an unlisted currency code is shown as-is in front of the amount" do
    Forefront.currency = "JPY"
    assert_equal "JPY 1,234.50", format_money(1234.5)
    assert_equal "JPY", currency_symbol
  end

  test "blank amounts render nothing" do
    assert_nil format_money(nil)
  end
end
