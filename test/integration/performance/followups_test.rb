require "test_helper"

class Forefront::Performance::FollowupsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source)
  end

  def followup(scheduled_for, status: "pending", completed_at: nil)
    @lead.followups.create!(assigned_to: @ravi, created_by: @ravi, followup_type: "call", scheduled_for: scheduled_for,
                            status: status, completed_at: completed_at)
  end

  test "done by the end of the scheduled day counts as on time; cancelled ones and ones outside the period don't count" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      followup(Time.zone.local(2026, 10, 3, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 3, 18))
      followup(Time.zone.local(2026, 10, 4, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 5, 9))
      followup(Time.zone.local(2026, 10, 6, 10))
      followup(Time.zone.local(2026, 10, 7, 10), status: "cancelled")
      followup(Time.zone.local(2026, 9, 20, 10), status: "completed", completed_at: Time.zone.local(2026, 9, 20, 11))
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 3 (33%)", cell("Ravi Rep", "followup_discipline")
      assert_equal "1", cell("Ravi Rep", "overdue_now")
      assert_equal 3, drill(:followups_due, member_id: @ravi.id).size
      assert_equal 1, drill(:followups_on_time, member_id: @ravi.id).size
    end
  end
end
