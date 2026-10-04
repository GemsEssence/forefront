require "test_helper"

# Adding a note takes the same right as adding a Followup: being allowed to
# work on the record. Anyone signed in used to be able to note on any Lead or Ticket.
class Forefront::ActivityAuthorizationTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  NOT_AUTHORIZED = "You are not authorized to perform this action."

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @owner = dashboard_staff("Olga Owner", "sales_person", manager: @manager)
    @assignee = dashboard_staff("Asha Assignee", "sales_person")
    @participant = dashboard_staff("Ravi Rep", "sales_person")
    @outsider = dashboard_staff("Omar Outsider", "sales_person")
    @admin = dashboard_staff("Ada Admin", "admin")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @owner, assigned_to: @owner, source: forefront_source)
    @assigned_lead = Forefront::Lead.create!(title: "Assigned", description: "D", customer: customer, created_by: @owner, assigned_to: @assignee, source: forefront_source)
    @lead.assignments.create!(to_user: @participant, changed_by: @owner)
    @lead.assignments.create!(to_user: @owner, from_user: @participant, changed_by: @participant)
    share = Forefront::LeadShare.new(lead: @lead, recorded_by: @owner)
    share.lead_share_participants.build(admin: @owner, percentage: 70)
    share.lead_share_participants.build(admin: @participant, percentage: 30)
    share.save!
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: customer, created_by: @owner, assigned_to: @assignee, category: "request", priority: "medium")
  end

  def note(path)
    post path, params: { activity: { activity_type: "comment", body: "A note" } }
  end

  test "an outsider cannot add a note to a lead they cannot open" do
    sign_in_as(@outsider)
    assert_no_difference -> { Forefront::Activity.count } do
      note "/forefront/leads/#{@lead.id}/activities"
    end
    assert_redirected_to "/forefront/"
    assert_equal NOT_AUTHORIZED, flash[:alert]
  end

  test "an outsider cannot add a note to a ticket they cannot open" do
    sign_in_as(@outsider)
    assert_no_difference -> { Forefront::Activity.count } do
      note "/forefront/tickets/#{@ticket.id}/activities"
    end
    assert_redirected_to "/forefront/"
    assert_equal NOT_AUTHORIZED, flash[:alert]
  end

  test "people who work on a lead can add a note" do
    [ @owner, @manager, @admin, @participant ].each do |person|
      sign_in_as(person)
      assert_difference -> { @lead.activities.count }, 1, "#{person.name} should be able to note" do
        note "/forefront/leads/#{@lead.id}/activities"
      end
      assert_redirected_to "/forefront/leads/#{@lead.id}"
    end
  end

  test "a lead's assignee can add a note" do
    sign_in_as(@assignee)
    assert_difference -> { @assigned_lead.activities.count }, 1 do
      note "/forefront/leads/#{@assigned_lead.id}/activities"
    end
  end

  test "a ticket's owner and assignee can add a note" do
    [ @owner, @assignee ].each do |person|
      sign_in_as(person)
      assert_difference -> { @ticket.activities.count }, 1, "#{person.name} should be able to note" do
        note "/forefront/tickets/#{@ticket.id}/activities"
      end
    end
  end

  test "the note form shows for a participant" do
    sign_in_as(@participant)
    get "/forefront/leads/#{@lead.id}"
    assert_match "Add Activity", response.body
  end

  test "someone who can only see an unassigned ticket in the pool gets no note form and cannot post a note" do
    product = Forefront::Product.create!(name: "Widget")
    product.admins << @outsider
    pooled = Forefront::Ticket.create!(title: "Pool", description: "D", customer: @ticket.customer, product: product,
                                       created_by: Forefront::Admin.system_actor, category: "signup", priority: "high", status: "open")
    sign_in_as(@outsider)

    get "/forefront/tickets/#{pooled.id}"
    assert_response :success
    assert_no_match "Add Activity", response.body

    assert_no_difference -> { Forefront::Activity.count } do
      note "/forefront/tickets/#{pooled.id}/activities"
    end
  end
end
