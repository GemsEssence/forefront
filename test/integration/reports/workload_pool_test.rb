require "test_helper"

class Forefront::Reports::WorkloadPoolTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def rows
    css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
  end

  def ticket(assigned_to: nil, audited: true)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @manager, assigned_to: assigned_to,
                                       category: "signup", priority: "high", status: "open")
    Forefront::AuditEvent.record!(actor: @manager, action: "created", auditable: ticket) if audited
    ticket
  end

  test "workload per person now" do
    2.times { Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, category: "request", priority: "medium", status: "open") }
    sign_in_as(@manager)

    get "/forefront/reports/workload"

    assert_equal [ "2", "0", "0", "0" ], rows["Ravi Rep"]
  end

  test "workload lists only the Manager's team" do
    outsider = dashboard_staff("Olga Outsider", "sales_person", manager: dashboard_staff("Other Boss", "manager"))
    sign_in_as(@manager)

    get "/forefront/reports/workload"

    assert_includes rows.keys, "Ravi Rep"
    assert_not_includes rows.keys, outsider.name
  end

  test "pool: what entered, what's still unclaimed, and who claimed how fast" do
    pooled = travel_to(3.hours.ago) { ticket }
    travel_to(1.hour.ago) { pooled.assignments.create!(to_user: @ravi, changed_by: @ravi, from_user: nil); pooled.update_columns(assigned_to_id: @ravi.id) }
    ticket
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_equal [ "2", "1", "—" ], rows["All"]
    assert_equal [ "—", "1", "2.0" ], rows["Ravi Rep"]
  end

  test "pool: records created assigned, before the period, or without a created event never entered the pool" do
    ticket(assigned_to: @ravi)
    travel_to(40.days.ago) { ticket }
    ticket(audited: false)
    ticket
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_equal [ "1", "1", "—" ], rows["All"]
  end
end
