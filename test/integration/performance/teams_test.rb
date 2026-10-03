require "test_helper"

class Forefront::Performance::TeamsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @mona = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @mona)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @mona)
    @omar = dashboard_staff("Omar Manager", "manager")
    @lena = dashboard_staff("Lena Loner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def enquiry(owner, converted:)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                       category: "enquiry", priority: "medium", status: "resolved")
    Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: "Resolved", changed_by: owner)
    Forefront::AuditEvent.record!(actor: owner, action: "converted", auditable: ticket, audited_changes: {}) if converted
  end

  test "an admin sees one row per team plus No manager, and rates add their parts" do
    enquiry(@ravi, converted: true)
    3.times { enquiry(@sara, converted: false) }
    sign_in_as(@admin)

    get "/forefront/performance"

    assert_equal [ "Mona Manager", "No manager", "Omar Manager" ], row_labels.sort
    assert_equal "1 of 4 (25%)", cell("Mona Manager", "ticket_to_lead")
    assert_select "tr[data-row='Mona Manager'] a[href*='manager_id=#{@mona.id}']"
  end

  test "the No manager row only appears when such sales persons exist" do
    @lena.destroy!
    sign_in_as(@admin)

    get "/forefront/performance"

    assert_equal [ "Mona Manager", "Omar Manager" ], row_labels.sort
  end

  test "clicking a team shows its people; No manager shows those without one" do
    sign_in_as(@admin)

    get "/forefront/performance", params: { manager_id: @mona.id }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels.sort

    get "/forefront/performance", params: { manager_id: "none" }
    assert_equal [ "Lena Loner" ], row_labels
  end

  test "the Manager filter keeps No manager selected through another Apply" do
    sign_in_as(@admin)

    get "/forefront/performance", params: { manager_id: "none" }
    assert_select "select[name='manager_id'] option[selected][value='none']", text: "No manager"

    get "/forefront/performance", params: { manager_id: "none", period: "year" }
    assert_equal [ "Lena Loner" ], row_labels
  end

  test "a sales person whose manager is no longer a manager lands under No manager" do
    stray = dashboard_staff("Stray Seller", "sales_person", manager: @sara)
    sign_in_as(@admin)

    get "/forefront/performance"
    assert_includes row_labels, "No manager"

    get "/forefront/performance", params: { manager_id: "none" }
    assert_equal [ "Lena Loner", "Stray Seller" ], row_labels.sort
    assert stray
  end

  def shared_receipt(owner, other, amount)
    lead = Forefront::Lead.create!(title: "Joint", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                   source: forefront_source, status: "won", actual_amount: amount)
    payment = Forefront::Payment.create!(lead: lead, total_amount: amount)
    Forefront::Receipt.create!(payment: payment, amount: amount, received_on: Date.current, payment_method: "cash", recorded_by: owner)
    lead.assignments.create!(to_user: other, changed_by: owner, from_user: owner)
    share = Forefront::LeadShare.new(lead: lead, recorded_by: owner)
    share.lead_share_participants.build(admin: owner, percentage: 50)
    share.lead_share_participants.build(admin: other, percentage: 50)
    share.save!
  end

  test "team revenue sums members' shares: inside one team 100%, across teams 50% each" do
    shared_receipt(@ravi, @sara, 1_000)
    shared_receipt(@ravi, @lena, 2_000)
    sign_in_as(@admin)

    get "/forefront/performance"

    assert_equal "₹2,000.00", cell("Mona Manager", "revenue_collected")
    assert_equal "₹1,000.00", cell("No manager", "revenue_collected")
  end
end
