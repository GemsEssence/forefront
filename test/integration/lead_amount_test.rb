require "test_helper"

# A Lead carries an estimated amount from creation, and an actual amount that
# is asked for when it's marked won (the deal can close for a different
# figure). Amount-based Targets count the actual amount.
class Forefront::LeadAmountTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "the lead form captures an estimated amount, shown on the lead page" do
    get "/forefront/leads/new"
    assert_select "input[name='lead[estimated_amount]']"
    assert_select "input[name='lead[actual_amount]']", count: 0

    post "/forefront/leads", params: { lead: { title: "Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product.id, estimated_amount: "2500.50" } }
    lead = Forefront::Lead.order(:created_at).last

    assert_equal BigDecimal("2500.50"), lead.estimated_amount
    follow_redirect!
    assert_includes response.body, "₹2,500.50"
  end

  test "amounts can't be negative" do
    lead = build_lead(estimated_amount: -1, actual_amount: -1)

    assert_not lead.valid?
    assert lead.errors[:estimated_amount].any?
    assert lead.errors[:actual_amount].any?
  end

  test "marking a lead won requires the actual amount" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!

    assert_not lead.update(status: "won")
    assert_includes lead.errors[:actual_amount], "can't be blank"

    assert lead.update(status: "won", actual_amount: 900)
  end

  test "leads that were won before actual amounts existed stay editable" do
    lead = build_lead
    lead.save!
    lead.update_columns(status: "Won", won_at: Time.current)

    assert lead.reload.update(title: "Renamed")
  end

  test "the status modal asks for the actual amount, pre-filled with the estimate" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!

    get "/forefront/leads/#{lead.id}"
    assert_select "#status_history_modal_lead_#{lead.id} input[name='status_history[actual_amount]'][value='1000.0']"
  end

  test "winning through the status modal records the actual amount" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!

    post "/forefront/leads/#{lead.id}/status_histories",
         params: { status_history: { status: "won", actual_amount: "850" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{lead.id}" }

    assert_redirected_to "/forefront/leads/#{lead.id}"
    assert lead.reload.won?
    assert_equal 850, lead.actual_amount
    assert_equal 1000, lead.estimated_amount
  end

  test "winning through the status modal without an actual amount is refused" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!

    post "/forefront/leads/#{lead.id}/status_histories",
         params: { status_history: { status: "won", actual_amount: "" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{lead.id}" }

    assert_redirected_to "/forefront/leads/#{lead.id}"
    assert_match "Actual amount can't be blank", flash[:alert]
    assert_not lead.reload.won?
    assert_equal 0, lead.status_histories.count
  end

  test "a won lead's actual amount can be corrected on the edit form" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!
    lead.update!(status: "won", actual_amount: 900)

    get "/forefront/leads/#{lead.id}/edit"
    assert_select "input[name='lead[actual_amount]'][value='900.0']"
  end

  test "recording a payment starts from the actual amount" do
    lead = build_lead(estimated_amount: 1000)
    lead.save!
    lead.update!(status: "won", actual_amount: 1200)

    get "/forefront/leads/#{lead.id}/payment/new"
    assert_select "input[name='payment[total_amount]'][value='1200.0']"
  end

  test "the CSV export includes both amounts" do
    lead = build_lead(estimated_amount: 750)
    lead.save!
    lead.update!(status: "won", actual_amount: 700)

    get "/forefront/leads.csv"
    header, row = CSV.parse(response.body)
    assert_equal "750.0", row[header.index("Estimated Amount")]
    assert_equal "700.0", row[header.index("Actual Amount")]
  end

  private

  def build_lead(**attrs)
    Forefront::Lead.new(title: "Deal", description: "D", customer: @customer, created_by: @admin, source: forefront_source, **attrs)
  end
end
