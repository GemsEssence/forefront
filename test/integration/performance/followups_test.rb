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

  def followup(scheduled_for, title, status: "pending", completed_at: nil)
    lead = Forefront::Lead.create!(title: title, description: "D", customer: @lead.customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source)
    lead.followups.create!(assigned_to: @ravi, created_by: @ravi, followup_type: "call", scheduled_for: scheduled_for,
                           status: status, completed_at: completed_at)
  end


  test "done by the end of the scheduled day counts as on time; cancelled, not-yet-due and out-of-period ones don't count" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      followup(Time.zone.local(2026, 10, 3, 10), "OnTime", status: "completed", completed_at: Time.zone.local(2026, 10, 3, 18))
      followup(Time.zone.local(2026, 10, 4, 10), "Late", status: "completed", completed_at: Time.zone.local(2026, 10, 5, 9))
      followup(Time.zone.local(2026, 10, 6, 10), "Missed")
      followup(Time.zone.local(2026, 10, 7, 10), "Cancelled", status: "cancelled")
      followup(Time.zone.local(2026, 9, 20, 10), "LastMonth", status: "completed", completed_at: Time.zone.local(2026, 9, 20, 11))
      followup(Time.zone.local(2026, 10, 25, 10), "Later")
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 3 (33%)", cell("Ravi Rep", "followup_discipline")
      assert_equal "1", cell("Ravi Rep", "overdue_now")
      due = drill(:followups_due, member_id: @ravi.id)
      assert_equal 3, due.size
      %w[OnTime Late Missed].each { |name| assert due.one? { |row| row.start_with?(name) }, "#{name} missing from #{due}" }
      %w[Cancelled LastMonth Later].each { |name| assert due.none? { |row| row.start_with?(name) }, "#{name} should be absent" }
      on_time = drill(:followups_on_time, member_id: @ravi.id)
      assert_equal 1, on_time.size
      assert on_time.first.start_with?("OnTime")
    end
  end

  test "a pending followup from before the period still counts as overdue now" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      followup(Time.zone.local(2026, 9, 20, 10), "Old")
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1", cell("Ravi Rep", "overdue_now")
      assert_equal "—", cell("Ravi Rep", "followup_discipline")
    end
  end

  test "the scheduled day ends at local midnight, not UTC midnight" do
    Time.use_zone("Asia/Kolkata") do
      travel_to Time.zone.local(2026, 10, 15, 12) do
        followup(Time.zone.local(2026, 10, 4, 10), "BeforeMidnight", status: "completed", completed_at: Time.zone.local(2026, 10, 4, 23, 59))
        followup(Time.zone.local(2026, 10, 5, 10), "AfterMidnight", status: "completed", completed_at: Time.zone.local(2026, 10, 6, 0, 1))
        sign_in_as(@manager)

        get "/forefront/performance"

        assert_equal "1 of 2 (50%)", cell("Ravi Rep", "followup_discipline")
      end
    end
  end
end
