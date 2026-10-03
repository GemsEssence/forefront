require "test_helper"

class Forefront::Performance::DealsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def won(title, amount, created_days_ago)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                            status: "won", actual_amount: amount, created_at: created_days_ago.days.ago)
  end

  test "demos, average won amount and average days from created to won" do
    won("Small", 1_000, 2)
    won("Big", 3_000, 4)
    demo = Forefront::Lead.create!(title: "Demoed", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "demo")
    Forefront::StatusHistory.create!(trackable: demo, old_status: "Contacted", new_status: "Demo", changed_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1", cell("Ravi Rep", "demos_done")
    assert_equal "₹2,000.00", cell("Ravi Rep", "avg_deal_size")
    assert_equal "3.0 d", cell("Ravi Rep", "avg_sales_cycle")
    assert_equal "—", cell("Mona Manager", "avg_deal_size")
  end

  test "a Lead won before the period does not affect the averages" do
    won("Small", 1_000, 2)
    won("Big", 3_000, 4)
    old = won("Old win", 90_000, 100)
    old.update_columns(won_at: 2.months.ago)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "₹2,000.00", cell("Ravi Rep", "avg_deal_size")
    assert_equal "3.0 d", cell("Ravi Rep", "avg_sales_cycle")
  end
end
