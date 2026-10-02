require "test_helper"

class Forefront::Dashboard::SharedWithMeTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @owner = dashboard_staff("Olga Owner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  test "leads someone else owns but shares with me show my percentage and next followup" do
    lead = Forefront::Lead.create!(title: "Joint Deal", description: "D", customer: @customer, created_by: @owner, assigned_to: @rep, source: forefront_source)
    lead.assignments.create!(to_user: @rep, changed_by: @owner)
    lead.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    lead.update!(assigned_to: @owner)
    share = Forefront::LeadShare.new(lead: lead, recorded_by: @owner)
    share.lead_share_participants.build(admin: @owner, percentage: 70)
    share.lead_share_participants.build(admin: @rep, percentage: 30)
    share.save!
    lead.followups.create!(assigned_to: @owner, created_by: @owner, followup_type: "call", scheduled_for: Time.zone.parse("#{Date.tomorrow} 10:00"))
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:shared_with_me)
    assert_match(/Joint Deal.*30%.*#{Date.tomorrow.strftime("%-d %b")}/, widget("shared_with_me").text.squish)
    assert_match "Joint Deal", drill(:shared_with_me).first
  end

  test "an admin can't open it" do
    sign_in_as(dashboard_staff("Asha Admin", "admin"))
    get "/forefront/dashboard/metrics/shared_with_me"
    assert_redirected_to "/forefront/"
  end
end
