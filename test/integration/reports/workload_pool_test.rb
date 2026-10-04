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

    assert_equal [ "2", "1", "—", "—" ], rows["All"]
    assert_equal [ "—", "—", "1", "2.0" ], rows["Ravi Rep"]
  end

  test "pool: records created assigned, before the period, or without a created event never entered the pool" do
    ticket(assigned_to: @ravi)
    travel_to(40.days.ago) { ticket }
    ticket(audited: false)
    ticket
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_equal [ "1", "1", "—", "—" ], rows["All"]
  end

  def lead(assigned_to: nil, **attrs)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @manager, assigned_to: assigned_to,
                                   source: forefront_source("Web"), status: "open", **attrs)
    Forefront::AuditEvent.record!(actor: @manager, action: "created", auditable: lead)
    lead
  end

  def claim(record, by:, hours_ago:)
    travel_to(hours_ago.hours.ago) { record.assignments.create!(to_user: by, changed_by: by, from_user: nil) }
    record.update_columns(assigned_to_id: by.id)
  end

  test "pool: a Lead created unassigned counts as entering the pool" do
    lead
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_equal [ "1", "1", "—", "—" ], rows["All"]
  end

  test "pool: a created event with a blank assignee still counts" do
    ticket = ticket(audited: false)
    Forefront::AuditEvent.create!(actor: @manager, action: "created", auditable: ticket, auditable_label: "T", audited_changes: { "assigned_to" => [ nil, nil ] })
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_equal [ "1", "1", "—", "—" ], rows["All"]
  end

  test "pool: a record the claimer created and assigned to themselves is not a claim" do
    own = Forefront::Ticket.create!(title: "Mine", description: "D", customer: @customer, created_by: @ravi, category: "signup", priority: "high", status: "open")
    claim(own, by: @ravi, hours_ago: 1)
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_nil rows["Ravi Rep"]
  end

  test "pool: the campaign filter narrows entered pool and claims" do
    source = forefront_source("Web")
    spring = Forefront::Campaign.create!(name: "Spring", source: source, created_by: @manager, starts_on: 30.days.ago.to_date, ends_on: 1.day.from_now.to_date)
    in_campaign = ticket
    in_campaign.update_columns(campaign_id: spring.id)
    other = ticket
    claim(in_campaign, by: @ravi, hours_ago: 1)
    claim(other, by: @ravi, hours_ago: 1)
    ticket
    sign_in_as(@manager)

    get "/forefront/reports/pool", params: { campaign_id: spring.id }

    assert_equal [ "1", "0", "—", "—" ], rows["All"]
    assert_equal [ "—", "—", "1" ], rows["Ravi Rep"].first(3)
  end

  test "pool: the product filter narrows entered pool and claims" do
    widget = Forefront::Product.create!(name: "Widget")
    gadget = Forefront::Product.create!(name: "Gadget")
    [ widget, gadget ].each { |product| Forefront::ProductAllocation.create!(admin: @ravi, product: product) }
    widget_ticket = ticket
    widget_ticket.update_columns(product_id: widget.id)
    gadget_ticket = ticket
    gadget_ticket.update_columns(product_id: gadget.id)
    claim(widget_ticket, by: @ravi, hours_ago: 1)
    claim(gadget_ticket, by: @ravi, hours_ago: 1)
    sign_in_as(@manager)

    get "/forefront/reports/pool", params: { product_id: widget.id }

    assert_equal [ "1", "0", "—", "—" ], rows["All"]
    assert_equal "1", rows["Ravi Rep"][2]
  end

  test "pool: a claim on a deleted record does not raise" do
    gone = ticket
    claim(gone, by: @ravi, hours_ago: 1)
    gone.delete
    sign_in_as(@manager)

    get "/forefront/reports/pool"

    assert_response :success
    assert_nil rows["Ravi Rep"]
  end
end
