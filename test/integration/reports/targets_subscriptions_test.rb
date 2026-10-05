require "test_helper"

class Forefront::Reports::TargetsSubscriptionsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @widget = Forefront::Product.create!(name: "Widget")
    @widget.admins << @ravi
  end

  def rows
    css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
  end

  def other_team_rep
    other_manager = dashboard_staff("Otto Manager", "manager")
    olga = dashboard_staff("Olga Other", "sales_person", manager: other_manager)
    @widget.admins << olga
    olga
  end

  # A won Lead on `product` for `person` whose Subscription expires `days` from today.
  def subscription_in(days, person: @ravi, product: @widget)
    @subscriptions = (@subscriptions || 0) + 1
    customer = Forefront::Customer.create!(name: "C#{@subscriptions}", phone: format("555-03%02d", @subscriptions))
    Forefront::Lead.create!(title: "S#{@subscriptions}", description: "D", customer: customer, created_by: person, assigned_to: person,
                            source: forefront_source, product: product, status: "won", actual_amount: 1, expires_at: Date.current + days)
  end

  test "targets overlapping the period with goal, achieved, gap and percent" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      Forefront::Target.create!(admin: @ravi, product: @widget, metric: "amount", period: "monthly", goal_value: 10_000, starts_on: Date.new(2026, 10, 1))
      Forefront::Target.create!(admin: @ravi, product: @widget, metric: "amount", period: "monthly", goal_value: 5_000, starts_on: Date.new(2026, 8, 1))
      customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
      Forefront::Lead.create!(title: "W", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                              product: @widget, status: "won", actual_amount: 2_500)
      sign_in_as(@manager)

      get "/forefront/reports/targets"

      assert_equal [ [ "Ravi Rep", "Widget", "Monthly from 1 Oct 2026", "Amount", "10,000.00", "2,500.00", "7,500.00", "25%" ] ], rows
    end
  end

  test "a target ending the day before the period is excluded; one starting on its last day is included" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      Forefront::Target.create!(admin: @ravi, product: @widget, metric: "lead_count", period: "monthly", goal_value: 4, starts_on: Date.new(2026, 9, 1))
      Forefront::Target.create!(admin: @ravi, product: @widget, metric: "lead_count", period: "monthly", goal_value: 5, starts_on: Date.new(2026, 11, 1))
      sign_in_as(@manager)

      get "/forefront/reports/targets", params: { period: "custom", from: "2026-10-01", to: "2026-11-01" }

      assert_equal [ [ "Ravi Rep", "Widget", "Monthly from 1 Nov 2026", "Lead count", "5.00", "0.00", "5.00", "0%" ] ], rows
    end
  end

  test "a manager does not see another team's targets" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      olga = other_team_rep
      Forefront::Target.create!(admin: @ravi, product: @widget, metric: "amount", period: "monthly", goal_value: 1_000, starts_on: Date.new(2026, 10, 1))
      Forefront::Target.create!(admin: olga, product: @widget, metric: "amount", period: "monthly", goal_value: 9_000, starts_on: Date.new(2026, 10, 1))
      sign_in_as(@manager)

      get "/forefront/reports/targets"

      assert_equal [ "Ravi Rep" ], rows.map(&:first)
    end
  end

  test "subscriptions per product by time to expiry" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      [ 3, 20, 45, 90, -5 ].each { |days| subscription_in(days) }
      sign_in_as(@manager)

      get "/forefront/reports/subscriptions"

      assert_equal [ "Widget", "1", "1", "1", "1", "1" ], rows.find { |row| row.first == "Widget" }
    end
  end

  test "subscription bands meet at their boundaries: today counts as 0–7 days, yesterday as expired" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      [ -1, 0, 7, 8, 30, 31, 60, 61 ].each { |days| subscription_in(days) }
      sign_in_as(@manager)

      get "/forefront/reports/subscriptions"

      assert_equal [ [ "Widget", "1", "2", "2", "2", "1" ] ], rows
    end
  end

  test "a manager does not see another team's subscriptions" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      olga = other_team_rep
      gadget = Forefront::Product.create!(name: "Gadget")
      gadget.admins << olga
      subscription_in(90)
      subscription_in(90, person: olga)
      subscription_in(3, person: olga, product: gadget)
      sign_in_as(@manager)

      get "/forefront/reports/subscriptions"

      assert_equal [ [ "Widget", "1", "0", "0", "0", "0" ] ], rows
    end
  end
end
