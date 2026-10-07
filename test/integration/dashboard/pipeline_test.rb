require "test_helper"

class Forefront::Dashboard::PipelineTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @partner = dashboard_staff("Pia Partner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, status: "open", amount: 1000, owner: @rep)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                            source: forefront_source, status: status, estimated_amount: amount, actual_amount: (amount if status == "won"))
  end

  test "open leads are counted and valued by stage, and shared ones are marked" do
    lead("A", status: "demo", amount: 1000)
    shared = lead("B", status: "demo", amount: 500)
    shared.assignments.create!(to_user: @partner, changed_by: @rep, from_user: @rep)
    share = Forefront::LeadShare.new(lead: shared, recorded_by: @rep)
    share.lead_share_participants.build(admin: @rep, percentage: 60)
    share.lead_share_participants.build(admin: @partner, percentage: 40)
    share.save!
    lead("C", status: "won")
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "2", metric(:pipeline, slice: "demo")
    assert_equal "₹1,500.00", css_select("[data-metric='pipeline'][data-slice='demo'][data-sum]").first&.text&.squish
    assert_equal "1", metric(:pipeline_shared, slice: "demo")
    assert_nil metric(:pipeline, slice: "won")
    assert_equal [ "A", "B" ], drill(:pipeline, slice: "demo").map { |row| row.split.first }.sort
  end

  test "an unknown stage lists nothing" do
    lead("A", status: "demo")
    sign_in_as(@rep)

    assert_empty drill(:pipeline, slice: "bogus")
  end

  test "open leads with no pending followup are orphans" do
    lead("Forgotten")
    lead("Looked after").followups.create!(assigned_to: @rep, created_by: @rep, followup_type: "call", scheduled_for: 1.day.from_now)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:needs_next_step)
    assert_match "Forgotten", drill(:needs_next_step).first
  end
end
