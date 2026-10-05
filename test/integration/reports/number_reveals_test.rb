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
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @acme, created_by: @ravi, assigned_to: @ravi, category: "request", priority: "medium", status: "open")
      Forefront::ContactReveal.create!(admin: @ravi, customer: @acme, created_at: Time.zone.local(2026, 10, 20, 10))
      Forefront::AuditEvent.record!(actor: @ravi, action: "added_activity", auditable: ticket, audited_changes: {})
      Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: Time.zone.local(2026, 10, 20, 11))
      Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: Time.zone.local(2026, 10, 20, 11, 30))
      sign_in_as(@admin)

      get "/forefront/reports/number_reveals"

      row = css_select("table[data-report] tbody tr").map { |tr| css_select(tr, "td").map { |cell| cell.text.squish } }.find { |cells| cells[0] == "Ravi Rep" }
      assert_equal [ "Ravi Rep", "3", "2", "2" ], row

      sign_in_as(@ravi)
      get "/forefront/reports/number_reveals"
      assert_redirected_to "/forefront/"
    end
  end

  test "reveals respect period boundaries" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      # Reveal before period (Sept 30, 23:59:59) should not be counted
      Forefront::ContactReveal.create!(admin: @ravi, customer: @acme, created_at: Time.zone.local(2026, 9, 30, 23, 59, 59))
      # Reveal at period start (Oct 1, 00:00:00) should be counted
      Forefront::ContactReveal.create!(admin: @ravi, customer: @beta, created_at: Time.zone.local(2026, 10, 1, 0, 0, 0))
      sign_in_as(@admin)

      get "/forefront/reports/number_reveals"

      row = css_select("table[data-report] tbody tr").map { |tr| css_select(tr, "td").map { |cell| cell.text.squish } }.find { |cells| cells[0] == "Ravi Rep" }
      # Only 1 reveal (the one at period start), 1 customer
      assert_equal [ "Ravi Rep", "1", "1", "1" ], row
    end
  end
end
