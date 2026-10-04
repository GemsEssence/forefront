# test/integration/reports/conversion_funnel_test.rb
require "test_helper"

class Forefront::Reports::ConversionFunnelTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  # An enquiry Ticket converted into a Lead that reaches `status`.
  def converted(status, history: [], paid: false, owner: @ravi, created_at: nil, audited: true)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                       category: "enquiry", priority: "medium", status: "resolved")
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                   source: forefront_source, status: status, actual_amount: (100 if status == "won"),
                                   lost_reason: (Forefront::LostReason.create!(name: "R#{SecureRandom.hex(2)}") if status == "lost"),
                                   lost_note: ("N" if status == "lost"))
    ticket.update_columns(lead_id: lead.id, **({ created_at: created_at } if created_at).to_h)
    Forefront::AuditEvent.record!(actor: @ravi, action: "converted", auditable: ticket, audited_changes: {}) if audited
    history.each { |stage| Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: Forefront::Lead.statuses.fetch(stage), changed_by: @ravi) }
    if paid
      payment = Forefront::Payment.create!(lead: lead, total_amount: 100)
      Forefront::Receipt.create!(payment: payment, amount: 100, received_on: Date.current, payment_method: "cash", recorded_by: @ravi)
    end
    lead
  end

  test "each step counts how many reached it, with drop-off from the previous and the first" do
    Forefront::Ticket.create!(title: "Never converted", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                              category: "signup", priority: "medium", status: "open")
    converted("contacted")
    converted("demo")
    converted("lost", history: %w[demo proposal])
    converted("won", paid: true)
    sign_in_as(@manager)

    get "/forefront/reports/conversion_funnel"

    rows = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
    counts = rows.to_h { |row| [ row[0], row[1] ] }
    assert_equal "5", counts["Enquiry or signup tickets"]
    assert_equal "4", counts["Converted to leads"]
    assert_equal "4", counts["Contacted"]
    assert_equal "3", counts["Demo"]
    assert_equal "2", counts["Proposal"]
    assert_equal "1", counts["Won"]
    assert_equal "1", counts["Paid in full"]
    assert_equal [ "Proposal", "2", "67%", "40%" ], rows.find { |row| row[0] == "Proposal" }
  end

  def step_counts
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }.to_h { |row| [ row[0], row[1] ] }
  end

  test "a ticket created before the period is not counted, nor its lead" do
    converted("won", created_at: 2.months.ago)
    converted("demo")
    sign_in_as(@manager)

    get "/forefront/reports/conversion_funnel"

    assert_equal "1", step_counts["Enquiry or signup tickets"]
    assert_equal "1", step_counts["Converted to leads"]
    assert_equal "0", step_counts["Won"]
  end

  test "a manager does not see another team's tickets or leads" do
    converted("won", owner: @otto)
    converted("demo")
    sign_in_as(@manager)

    get "/forefront/reports/conversion_funnel"

    assert_equal "1", step_counts["Enquiry or signup tickets"]
    assert_equal "1", step_counts["Converted to leads"]
    assert_equal "0", step_counts["Won"]
  end

  test "a converted ticket without a converted audit event still counts and follows through" do
    converted("won", audited: false, paid: true)
    sign_in_as(@manager)

    get "/forefront/reports/conversion_funnel"

    assert_equal "1", step_counts["Converted to leads"]
    assert_equal "1", step_counts["Won"]
    assert_equal "1", step_counts["Paid in full"]
  end
end
