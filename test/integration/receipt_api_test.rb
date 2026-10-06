require "test_helper"

# A Product's own application reporting money a Customer paid in it
# (CONTEXT.md: Unattached Receipt, ADR 0008).
class Forefront::ReceiptApiTest < ActionDispatch::IntegrationTest
  setup do
    @product = Forefront::Product.create!(name: "Widget")
    @key = @product.generate_api_key!
    @customer = Forefront::Customer.create!(name: "Priya", country_code: "+91", phone: "9876543210")
  end

  def report(body, key: @key)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{key}" if key
    post "/forefront/api/v1/receipts", params: body.to_json, headers: headers
  end

  def paid(**overrides)
    { phone: "+91 98765 43210", amount: "4999.00", paid_at: "2026-10-05", reference: "txn-881", method: "upi" }.merge(overrides)
  end

  def json
    JSON.parse(response.body)
  end

  test "a reported payment becomes an unattached receipt for the matched customer" do
    report(paid)

    assert_response :created
    receipt = Forefront::Receipt.sole
    assert_equal({ "status" => "ok", "id" => receipt.id }, json)
    assert_nil receipt.payment
    assert_equal [ @product, @customer, 4999, Date.new(2026, 10, 5), "upi", "txn-881" ],
                 [ receipt.product, receipt.customer, receipt.amount, receipt.received_on, receipt.payment_method, receipt.external_reference ]
    assert_equal Forefront::Admin.system_actor, receipt.recorded_by
    assert_includes Forefront::Receipt.unattached, receipt
  end

  test "the same reference reported again is answered with the first receipt, not a second" do
    report(paid)
    report(paid(amount: "4999.00"))

    assert_response :ok
    assert_equal 1, Forefront::Receipt.count
    assert_equal Forefront::Receipt.sole.id, json["id"]
  end

  test "an unknown phone is kept on the receipt for staff to match later, and an unknown method is Other" do
    report(paid(phone: "+91 11111 22222", method: "wallet"))

    assert_response :created
    receipt = Forefront::Receipt.sole
    assert_nil receipt.customer
    assert_equal [ "+91", "1111122222", "other" ], [ receipt.country_code, receipt.phone, receipt.payment_method ]
  end

  test "a bad key is refused, and a report missing its essentials says what's missing" do
    report(paid, key: "nope")
    assert_response :unauthorized

    report(paid(amount: "", reference: ""))
    assert_response :unprocessable_entity
    assert_equal [ "Amount must be greater than 0", "Reference can't be blank" ], json["errors"]
    assert_equal 0, Forefront::Receipt.count
  end
end
