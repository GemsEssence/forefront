require "test_helper"

# Staff attaching a Receipt a Product's application reported to the
# Payment or Installment it pays, or discarding a duplicate (CONTEXT.md:
# Unattached Receipt).
class Forefront::UnattachedReceiptsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @widget = forefront_product(allocated_to: @rep)
    @gadget = forefront_product("Gadget")
    @customer = Forefront::Customer.create!(name: "Acme", country_code: "+91", phone: "9876543210")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @widget, status: "won", actual_amount: 10_000)
    @payment = Forefront::Payment.create!(lead: @lead, total_amount: 10_000)
    @receipt = reported(@widget, amount: 4000, reference: "txn-1")
  end

  def reported(product, amount:, reference:, customer: @customer)
    Forefront::Receipt.create!(product: product, customer: customer, country_code: "+91", phone: customer&.phone || "5550100", amount: amount,
                               received_on: Date.new(2026, 10, 5), payment_method: "upi", external_reference: reference,
                               recorded_by: Forefront::Admin.system_actor)
  end

  test "a sales person sees the unattached receipts for their products and attaches one to the obvious payment" do
    reported(@gadget, amount: 1, reference: "txn-g")
    sign_in_as(@rep)

    get "/forefront/unattached_receipts"
    assert_response :success
    assert_select "tr[data-receipt='#{@receipt.id}']"
    assert_select "tr", text: /Gadget/, count: 0
    assert_select "tr[data-receipt='#{@receipt.id}'] select[name='target'] option[selected][value='payment:#{@payment.id}']"

    post "/forefront/unattached_receipts/#{@receipt.id}/attach", params: { target: "payment:#{@payment.id}" }

    assert_redirected_to "/forefront/unattached_receipts"
    @receipt.reload
    assert_equal @payment, @receipt.payment
    assert_equal 6000, @payment.reload.still_owed
    assert Forefront::AuditEvent.exists?(actor: @rep, action: "attached_receipt", auditable: @lead)
    get "/forefront/unattached_receipts"
    assert_select "tr[data-receipt='#{@receipt.id}']", count: 0
    get "/forefront/leads/#{@lead.id}"
    assert_match "txn-1", response.body
  end

  test "a receipt attaches to one installment and settles it" do
    first = @payment.installments.create!(amount: 4000, due_on: "2026-10-10")
    @payment.installments.create!(amount: 6000, due_on: "2026-11-10")
    sign_in_as(@rep)

    post "/forefront/unattached_receipts/#{@receipt.id}/attach", params: { target: "installment:#{first.id}" }

    assert first.reload.paid?
    assert_equal [ @payment, first ], [ @receipt.reload.payment, @receipt.installment ]
  end

  test "a receipt for more than is still owed stays unattached" do
    big = reported(@widget, amount: 12_000, reference: "txn-big")
    sign_in_as(@rep)

    post "/forefront/unattached_receipts/#{big.id}/attach", params: { target: "payment:#{@payment.id}" }

    assert_nil big.reload.payment
    assert_match "more than the 10,000.00 still owed", flash[:alert]
  end

  test "a won lead without a payment isn't offered, and one for another product isn't either" do
    other = Forefront::Customer.create!(name: "Globex", country_code: "+91", phone: "5550199")
    unpaid = Forefront::Lead.create!(title: "Unpaid", description: "D", customer: other, created_by: @rep, assigned_to: @rep,
                                     source: forefront_source, product: @widget, status: "won", actual_amount: 500)
    orphan = reported(@widget, amount: 100, reference: "txn-orphan", customer: nil)
    sign_in_as(@rep)

    get "/forefront/unattached_receipts"

    assert_select "tr[data-receipt='#{orphan.id}'] select[name='target'] option[value='payment:#{@payment.id}']"
    assert_select "tr[data-receipt='#{orphan.id}'] select[name='target'] option", text: /Unpaid/, count: 0
    assert_select "tr[data-receipt='#{orphan.id}'] td", text: /\+91 5550100/
    assert_nil unpaid.payment
  end

  test "a manager discards a duplicate with a note; a sales person can't" do
    sign_in_as(@rep)
    post "/forefront/unattached_receipts/#{@receipt.id}/discard", params: { note: "Duplicate" }
    assert_nil @receipt.reload.discarded_at

    sign_in_as(@manager)
    get "/forefront/unattached_receipts"
    assert_select "tr[data-receipt='#{@receipt.id}'] form[action='/forefront/unattached_receipts/#{@receipt.id}/discard']"
    post "/forefront/unattached_receipts/#{@receipt.id}/discard", params: { note: "Duplicate of txn-0" }

    @receipt.reload
    assert_equal [ @manager, "Duplicate of txn-0" ], [ @receipt.discarded_by, @receipt.discard_note ]
    assert_not_includes Forefront::Receipt.unattached, @receipt
    assert Forefront::AuditEvent.exists?(actor: @manager, action: "discarded_receipt")
    get "/forefront/unattached_receipts"
    assert_select "tr[data-receipt='#{@receipt.id}']", count: 0
  end
end
