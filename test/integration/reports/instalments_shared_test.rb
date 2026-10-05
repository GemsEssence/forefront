require "test_helper"

class Forefront::Reports::InstalmentsSharedTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @pia = dashboard_staff("Pia Partner", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def rows
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
  end

  def won_lead(title, person, amount)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: person, assigned_to: person,
                            source: forefront_source, status: "won", actual_amount: amount)
  end

  def mark_paid(installment, at)
    installment.update_columns(status: Forefront::Installment.statuses.fetch("paid"), paid_at: at)
  end

  # A Lead shared between `first` and `second` (60/40), with `received` paid in on `received_on`.
  def shared_lead(title, first, second, received:, received_on: Date.current)
    lead = won_lead(title, first, 1_000)
    lead.assignments.create!(to_user: first, changed_by: first)
    lead.assignments.create!(to_user: second, from_user: first, changed_by: first)
    share = Forefront::LeadShare.new(lead: lead, recorded_by: first)
    share.lead_share_participants.build(admin: first, percentage: 60)
    share.lead_share_participants.build(admin: second, percentage: 40)
    share.save!
    payment = Forefront::Payment.create!(lead: lead, total_amount: 1_000)
    Forefront::Receipt.create!(payment: payment, amount: received, received_on: received_on, payment_method: "cash", recorded_by: first)
    lead
  end

  test "instalments due in the period per lead: on time, late, overdue and balance outstanding" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      lead = won_lead("Deal", @ravi, 30_000)
      payment = Forefront::Payment.create!(lead: lead, total_amount: 30_000)
      mark_paid(payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 5)), Time.zone.local(2026, 10, 5, 9))
      mark_paid(payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 8)), Time.zone.local(2026, 10, 9, 9))
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 15))
      sign_in_as(@manager)

      get "/forefront/reports/instalments"

      assert_equal [ "Deal", "Acme", "Ravi Rep", "₹30,000.00", "1", "1", "1", "₹10,000.00" ], rows.first
    end
  end

  test "only instalments due inside the period are counted; the balance covers the whole lead less receipts" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      lead = won_lead("Deal", @ravi, 30_000)
      payment = Forefront::Payment.create!(lead: lead, total_amount: 30_000)
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 9, 30))
      inside = payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 1))
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 11, 1))
      Forefront::Receipt.create!(payment: payment, installment: inside, amount: 4_000, received_on: Date.current, payment_method: "cash", recorded_by: @ravi)
      sign_in_as(@manager)

      get "/forefront/reports/instalments"

      assert_equal [ [ "Deal", "Acme", "Ravi Rep", "₹10,000.00", "0", "0", "1", "₹26,000.00" ] ], rows
    end
  end

  test "instalments on another team's leads are left out" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      outsider = dashboard_staff("Olga Outsider", "sales_person", manager: dashboard_staff("Other Boss", "manager"))
      [ [ "Ours", @ravi ], [ "Theirs", outsider ] ].each do |title, person|
        payment = Forefront::Payment.create!(lead: won_lead(title, person, 5_000), total_amount: 5_000)
        payment.installments.create!(amount: 5_000, due_on: Date.new(2026, 10, 25))
      end
      sign_in_as(@manager)

      get "/forefront/reports/instalments"

      assert_equal [ "Ours" ], rows.map(&:first)
    end
  end

  test "shared leads with each participant's share and credit" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      shared_lead("Joint", @ravi, @pia, received: 1_000)
      sign_in_as(@manager)

      get "/forefront/reports/shared_leads"

      assert_equal [ "Joint", "Acme", "Ravi Rep 60% · Pia Partner 40%", "₹1,000.00", "Ravi Rep ₹600.00 · Pia Partner ₹400.00" ], rows.first
    end
  end

  test "only receipts dated inside the period are received and credited" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      shared_lead("Joint", @ravi, @pia, received: 1_000, received_on: Date.new(2026, 9, 30))
      sign_in_as(@manager)

      get "/forefront/reports/shared_leads"

      assert_equal [ [ "Joint", "Acme", "Ravi Rep 60% · Pia Partner 40%", "₹0.00", "Ravi Rep ₹0.00 · Pia Partner ₹0.00" ] ], rows
    end
  end

  test "credit lists only the participants in view, and shares with no one in view are left out" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      other_boss = dashboard_staff("Other Boss", "manager")
      olga = dashboard_staff("Olga Outsider", "sales_person", manager: other_boss)
      otto = dashboard_staff("Otto Outsider", "sales_person", manager: other_boss)
      shared_lead("Cross-team", @ravi, olga, received: 1_000)
      shared_lead("Theirs", olga, otto, received: 1_000)
      sign_in_as(@manager)

      get "/forefront/reports/shared_leads"

      assert_equal [ [ "Cross-team", "Acme", "Ravi Rep 60% · Olga Outsider 40%", "₹1,000.00", "Ravi Rep ₹600.00" ] ], rows
    end
  end
end
