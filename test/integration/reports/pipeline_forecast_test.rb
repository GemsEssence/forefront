require "test_helper"

class Forefront::Reports::PipelineForecastTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(status, due_at, amount, owner: @ravi)
    Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                            source: forefront_source, status: status, due_at: due_at, estimated_amount: amount, actual_amount: (amount if status == "won"))
  end

  test "open leads by due month and stage, with overdue and undated rows" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      lead("demo", Date.new(2026, 10, 20), 1_000)
      lead("proposal", Date.new(2026, 11, 5), 2_000)
      lead("demo", Date.new(2026, 9, 1), 500)
      lead("open", nil, 300)
      lead("won", Date.new(2026, 10, 25), 9_999)
      lead("demo", Date.new(2026, 10, 21), 7_777, owner: @otto)
      sign_in_as(@manager)

      get "/forefront/reports/pipeline_forecast"

      assert_response :success
      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      rows = css_select("table[data-report] tbody tr").map { |row| css_select(row, "td").map { |cell| cell.text.squish } }
      assert_equal [ "Overdue", "Oct 2026", "Nov 2026", "No date" ], rows.map(&:first)
      oct = rows.find { |row| row.first == "Oct 2026" }
      assert_equal "1", oct[headers.index("Demo")]
      assert_equal "₹1,000.00", oct[headers.index("Demo value")]
      assert_equal "1", oct[headers.index("Total")]
    end
  end
end
