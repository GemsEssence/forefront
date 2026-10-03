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
end
