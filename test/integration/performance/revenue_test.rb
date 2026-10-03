require "test_helper"

class Forefront::Performance::RevenueTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @pia = dashboard_staff("Pia Partner", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def paid_lead(title, owner, amount, received_on: Date.current)
    lead = Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                   source: forefront_source, status: "won", actual_amount: amount)
    payment = Forefront::Payment.create!(lead: lead, total_amount: amount)
    Forefront::Receipt.create!(payment: payment, amount: amount, received_on: received_on, payment_method: "cash", recorded_by: owner)
    lead
  end

  test "receipts credited by share, and the shared part shown separately" do
    paid_lead("Solo", @ravi, 1_000)
    shared = paid_lead("Joint", @ravi, 10_000)
    shared.assignments.create!(to_user: @pia, changed_by: @ravi, from_user: @ravi)
    share = Forefront::LeadShare.new(lead: shared, recorded_by: @ravi)
    share.lead_share_participants.build(admin: @ravi, percentage: 60)
    share.lead_share_participants.build(admin: @pia, percentage: 40)
    share.save!
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "₹7,000.00", cell("Ravi Rep", "revenue_collected")
    assert_equal "₹6,000.00", cell("Ravi Rep", "shared_revenue")
    assert_equal "₹4,000.00", cell("Pia Partner", "revenue_collected")
    assert_equal 2, drill(:receipts_credited, member_id: @ravi.id).size
    assert_equal 1, drill(:receipts_credited, member_id: @pia.id).size
  end

  test "a receipt received before the period does not count" do
    paid_lead("Old", @ravi, 5_000, received_on: 2.years.ago.to_date)
    paid_lead("New", @ravi, 2_000)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "₹2,000.00", cell("Ravi Rep", "revenue_collected")
    assert_equal 1, drill(:receipts_credited, member_id: @ravi.id).size
  end
end
