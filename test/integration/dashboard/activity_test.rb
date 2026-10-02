require "test_helper"

class Forefront::Dashboard::ActivityTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, **attributes)
    Forefront::Lead.create!({ title: title, description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source }.merge(attributes))
  end

  def moved(lead, to, at)
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: Forefront::Lead.statuses.fetch(to), changed_by: @rep, created_at: at)
  end

  test "demos, proposals, conversions, wins and losses in the period, each against the previous period" do
    big = lead("Big Deal")
    moved(big, "demo", 2.days.ago)
    moved(lead("Old Demo"), "demo", 40.days.ago)
    moved(lead("Second"), "demo", 1.hour.ago)
    moved(big, "proposal", 1.hour.ago)
    moved(lead("Gone", status: "lost", lost_reason: Forefront::LostReason.create!(name: "Price"), lost_note: "Too dear"), "lost", 1.hour.ago)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, category: "request", priority: "medium", status: "open")
    Forefront::AuditEvent.record!(actor: @rep, action: "converted", auditable: ticket, audited_changes: {})
    lead("Winner", status: "won", actual_amount: 100)
    sign_in_as(@rep)

    get "/forefront/", params: { period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 }

    assert_equal "2", metric(:demos)
    assert_equal "1", metric(:proposals)
    assert_equal "1", metric(:conversions)
    assert_equal "1", metric(:won)
    assert_equal "1", metric(:lost)
    assert_equal "▲ new", css_select("[data-change='demos']").first.text.squish
    assert_match "Big Deal", drill(:demos, period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601).join
  end

  test "a drop against the previous period shows as a fall" do
    moved(lead("A"), "demo", 10.days.ago)
    moved(lead("B"), "demo", 9.days.ago)
    moved(lead("C"), "demo", 1.day.ago)
    sign_in_as(@rep)

    get "/forefront/", params: { period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 }

    assert_equal "▼ 50%", css_select("[data-change='demos']").first.text.squish
  end
end
