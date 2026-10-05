require "test_helper"

class Forefront::Reports::NumberRevealsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @ravi = dashboard_staff("Ravi Rep", "sales_person")
    @acme = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @beta = Forefront::Customer.create!(name: "Beta", phone: "555-0101")
  end

  test "reveals per person, distinct customers, and reveals with no action after; admins only" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @acme, created_by: @ravi, assigned_to: @ravi, category: "request", priority: "medium", status: "open")
    travel_to(2.hours.ago) do
      Forefront::ContactReveal.create!(admin: @ravi, customer: @acme)
      Forefront::AuditEvent.record!(actor: @ravi, action: "added_activity", auditable: ticket, audited_changes: {})
    end
    Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: 1.hour.ago)
    Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: 30.minutes.ago)
    sign_in_as(@admin)

    get "/forefront/reports/number_reveals"

    row = css_select("table[data-report] tbody tr").map { |tr| css_select(tr, "td").map { |cell| cell.text.squish } }.find { |cells| cells[0] == "Ravi Rep" }
    assert_equal [ "Ravi Rep", "3", "2", "2" ], row

    sign_in_as(@ravi)
    get "/forefront/reports/number_reveals"
    assert_redirected_to "/forefront/"
  end

  test "reveals created before the period are not counted" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @acme, created_by: @ravi, assigned_to: @ravi, category: "request", priority: "medium", status: "open")
    # Create a reveal 3 months ago (before the default period)
    travel_to(3.months.ago) do
      Forefront::ContactReveal.create!(admin: @ravi, customer: @acme)
    end
    # Create a reveal within the current period
    Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: 1.hour.ago)
    sign_in_as(@admin)

    get "/forefront/reports/number_reveals"

    row = css_select("table[data-report] tbody tr").map { |tr| css_select(tr, "td").map { |cell| cell.text.squish } }.find { |cells| cells[0] == "Ravi Rep" }
    # Only 1 reveal (not 2), 1 customer (not 2)
    assert_equal [ "Ravi Rep", "1", "1", "1" ], row
  end
end
