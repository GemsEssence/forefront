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

  test "a participant can open the lead, so its title links to it" do
    lead = Forefront::Lead.create!(title: "Joint Deal", description: "D", customer: @customer, created_by: @owner, assigned_to: @rep, source: forefront_source)
    lead.assignments.create!(to_user: @rep, changed_by: @owner)
    lead.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    lead.update!(assigned_to: @owner)
    share_lead(lead, @owner => 70, @rep => 30)
    sign_in_as(@rep)

    get "/forefront/"

    assert_select "section[data-widget='shared_with_me'] a[href='/forefront/leads/#{lead.id}']", text: "Joint Deal"
    drill(:shared_with_me)
    assert_select "table[data-records] a[href='/forefront/leads/#{lead.id}']", text: "Joint Deal"
  end

  test "an admin can't open it" do
    sign_in_as(dashboard_staff("Asha Admin", "admin"))
    get "/forefront/dashboard/metrics/shared_with_me"
    assert_redirected_to "/forefront/"
  end

  test "leads I own, and leads shared only between other people, are not counted" do
    joint = Forefront::Lead.create!(title: "Joint Deal", description: "D", customer: @customer, created_by: @owner, assigned_to: @rep, source: forefront_source)
    joint.assignments.create!(to_user: @rep, changed_by: @owner)
    joint.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    joint.update!(assigned_to: @owner)
    share_lead(joint, @owner => 70, @rep => 30)

    mine = Forefront::Lead.create!(title: "My Own Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source)
    mine.assignments.create!(to_user: @rep, changed_by: @rep)
    mine.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    share_lead(mine, @rep => 60, @owner => 40)

    third = dashboard_staff("Tara Third", "sales_person")
    others = Forefront::Lead.create!(title: "Their Deal", description: "D", customer: @customer, created_by: @owner, assigned_to: @owner, source: forefront_source)
    others.assignments.create!(to_user: @owner, changed_by: @owner)
    others.assignments.create!(to_user: third, from_user: @owner, changed_by: @owner)
    share_lead(others, @owner => 50, third => 50)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:shared_with_me)
    rows = drill(:shared_with_me)
    assert_equal 1, rows.size
    assert_match "Joint Deal", rows.first
  end

  private

  def share_lead(lead, percentages)
    share = Forefront::LeadShare.new(lead: lead, recorded_by: @owner)
    percentages.each { |admin, percentage| share.lead_share_participants.build(admin: admin, percentage: percentage) }
    share.save!
  end
end
