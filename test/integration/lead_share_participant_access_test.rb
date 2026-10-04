require "test_helper"

# Someone a Lead is shared with may open it and work on it (notes, Followups),
# but not edit it, move it, reassign it or touch its money.
class Forefront::LeadShareParticipantAccessTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  NOT_AUTHORIZED = "You are not authorized to perform this action."

  setup do
    @owner = dashboard_staff("Olga Owner", "sales_person")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @outsider = dashboard_staff("Omar Outsider", "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Joint Deal", description: "D", customer: customer, created_by: @owner, assigned_to: @rep, source: forefront_source)
    @lead.assignments.create!(to_user: @rep, changed_by: @owner)
    @lead.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    @lead.update!(assigned_to: @owner)
    share = Forefront::LeadShare.new(lead: @lead, recorded_by: @owner)
    share.lead_share_participants.build(admin: @owner, percentage: 70)
    share.lead_share_participants.build(admin: @rep, percentage: 30)
    share.save!
  end

  def assert_refused
    assert_redirected_to "/forefront/"
    assert_equal NOT_AUTHORIZED, flash[:alert]
  end

  test "a participant opens the lead and sees the note and followup controls but no edit, stage, share or assign controls" do
    sign_in_as(@rep)
    get "/forefront/leads/#{@lead.id}"

    assert_response :success
    assert_match "Joint Deal", response.body
    assert_match "Add Activity", response.body
    assert_match "+ Add Followup", response.body
    assert_no_match(/>\s*Edit\s*</, response.body)
    assert_no_match "forefrontOpenModal('status_history_modal", response.body
    assert_no_match "forefrontOpenModal('assignment_modal", response.body
    assert_no_match "Edit Share", response.body
    assert_no_match "Mark as awaiting customer", response.body
  end

  test "someone the lead is not shared with still can't open it" do
    sign_in_as(@outsider)
    get "/forefront/leads/#{@lead.id}"
    assert_refused
  end

  test "a participant can add a note" do
    sign_in_as(@rep)
    assert_difference -> { @lead.activities.count }, 1 do
      post "/forefront/leads/#{@lead.id}/activities", params: { activity: { activity_type: "comment", body: "Spoke to them" } }
    end
    assert_redirected_to "/forefront/leads/#{@lead.id}"
  end

  test "a participant can schedule and update a followup" do
    sign_in_as(@rep)
    assert_difference -> { @lead.followups.count }, 1 do
      post "/forefront/leads/#{@lead.id}/followups", params: { followup: { assigned_to_id: @rep.id, followup_type: "call", scheduled_for: 2.days.from_now } }
    end
    followup = @lead.followups.last
    assert_equal "call", followup.followup_type

    patch "/forefront/leads/#{@lead.id}/followups/#{followup.id}", params: { followup: { outcome: "Left a message" } }
    assert_equal "Left a message", followup.reload.outcome
  end

  test "someone the lead is not shared with can't schedule followups" do
    sign_in_as(@outsider)
    assert_no_difference -> { @lead.followups.count } do
      post "/forefront/leads/#{@lead.id}/followups", params: { followup: { assigned_to_id: @outsider.id, followup_type: "call", scheduled_for: 2.days.from_now } }
    end
  end

  test "a participant can't edit the lead" do
    sign_in_as(@rep)
    patch "/forefront/leads/#{@lead.id}", params: { lead: { title: "Mine now" } }
    assert_refused
    assert_equal "Joint Deal", @lead.reload.title
  end

  test "a participant can't change the stage" do
    sign_in_as(@rep)
    assert_no_difference -> { @lead.status_histories.count } do
      post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "proposal" } }
    end
    assert_refused
  end

  test "a participant can't reassign the lead" do
    sign_in_as(@rep)
    assert_no_difference -> { @lead.assignments.count } do
      post "/forefront/leads/#{@lead.id}/assignments", params: { assignment: { to_user_id: @rep.id } }
    end
    assert_equal @owner.id, @lead.reload.assigned_to_id
  end

  test "a participant can't mark the lead awaiting customer" do
    sign_in_as(@rep)
    post "/forefront/leads/#{@lead.id}/awaiting_customer", params: { followup: { followup_type: "call", scheduled_for: 2.days.from_now } }
    assert_refused
    assert_not @lead.reload.awaiting_customer?
  end

  test "a participant can't record a payment, instalment, receipt or change the share" do
    sign_in_as(@rep)
    assert_no_difference -> { Forefront::Payment.count + Forefront::LeadShare.count } do
      post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: 100 } }
      assert_refused
      post "/forefront/leads/#{@lead.id}/payment/installments", params: { installment: { amount: 10, due_on: Date.tomorrow } }
      assert_refused
      post "/forefront/leads/#{@lead.id}/payment/receipts", params: { receipt: { amount: 10 } }
      assert_refused
      post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @owner.id => "50", @rep.id => "50" } } }
      assert_refused
    end
    assert_equal 30, @lead.lead_share.lead_share_participants.find_by(admin: @rep).percentage
  end
end
