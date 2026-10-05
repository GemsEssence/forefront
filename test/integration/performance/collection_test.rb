require "test_helper"

class Forefront::Performance::CollectionTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  # One Lead per instalment, so each drill row names its instalment by Lead title.
  def instalment(title, due_on, paid_at: nil)
    lead = Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "won", actual_amount: 10_000)
    payment = Forefront::Payment.create!(lead: lead, total_amount: 10_000)
    installment = payment.installments.create!(amount: 10_000, due_on: due_on)
    installment.update_columns(status: Forefront::Installment.statuses.fetch("paid"), paid_at: paid_at) if paid_at
    installment
  end

  def renewal(title, outcome, closed_at, status: "resolved")
    product = Forefront::Product.find_or_create_by!(name: "Widget")
    ticket = Forefront::Ticket.create!(title: title, description: "D", customer: @customer, product: product, created_by: @ravi,
                                       assigned_to: @ravi, category: "renewal", priority: "medium", status: status, renewal_outcome: outcome)
    Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: status.capitalize, changed_by: @ravi, created_at: closed_at)
    ticket
  end

  test "instalments paid by their due date out of those due" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      instalment("OnTime", Date.new(2026, 10, 5), paid_at: Time.zone.local(2026, 10, 5, 9))
      instalment("Late", Date.new(2026, 10, 10), paid_at: Time.zone.local(2026, 10, 12, 9))
      instalment("Unpaid", Date.new(2026, 10, 15))
      instalment("NotYetDue", Date.new(2026, 10, 25))
      instalment("LastMonth", Date.new(2026, 9, 28), paid_at: Time.zone.local(2026, 9, 28, 9))
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 3 (33%)", cell("Ravi Rep", "instalment_collection")
      due = drill(:instalments_due_in_period, member_id: @ravi.id)
      assert_equal 3, due.size
      %w[OnTime Late Unpaid].each { |name| assert due.one? { |row| row.start_with?(name) }, "#{name} missing from #{due}" }
      %w[NotYetDue LastMonth].each { |name| assert due.none? { |row| row.start_with?(name) }, "#{name} should be absent" }
      on_time = drill(:instalments_on_time, member_id: @ravi.id)
      assert_equal 1, on_time.size
      assert on_time.first.start_with?("OnTime")
    end
  end

  test "renewal tickets renewed out of those closed with an outcome" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      renewal("Renewed", "renewed", Time.zone.local(2026, 10, 3, 10))
      renewal("Declined", "declined", Time.zone.local(2026, 10, 4, 10), status: "closed")
      renewal("NoOutcome", nil, Time.zone.local(2026, 10, 5, 10))
      renewal("ClosedLastMonth", "renewed", Time.zone.local(2026, 9, 20, 10))
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 2 (50%)", cell("Ravi Rep", "renewal_rate")
      closed = drill(:renewals_closed, member_id: @ravi.id)
      assert_equal 2, closed.size
      %w[Renewed Declined].each { |name| assert closed.one? { |row| row.start_with?(name) }, "#{name} missing from #{closed}" }
      %w[NoOutcome ClosedLastMonth].each { |name| assert closed.none? { |row| row.start_with?(name) }, "#{name} should be absent" }
      renewed = drill(:renewals_renewed, member_id: @ravi.id)
      assert_equal 1, renewed.size
      assert renewed.first.start_with?("Renewed")
    end
  end
end
