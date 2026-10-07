require "test_helper"

# Every active Lead and unfinished Ticket has a Next step (CONTEXT.md): a
# pending Followup, the open demo or proposal Ticket under a Lead, or for a
# Ticket its due date. Creating a record asks for the first step.
class Forefront::NextStepTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @admin = dashboard_staff("Asha Admin", "admin")
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    travel_to Time.zone.local(2026, 10, 6, 9) # a Tuesday
  end

  def lead_params(**overrides)
    { title: "Big Deal", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: @product.id,
      due_at: "2026-10-20" }.merge(overrides)
  end

  def first_step(**overrides)
    { followup_type: "call", scheduled_for: "2026-10-07T10:00" }.merge(overrides)
  end

  test "the lead form asks for the first step, prefilled with a call on the next working day, and creates it for the assignee" do
    sign_in_as(@rep)
    get "/forefront/leads/new"
    assert_select "select[name='first_step[followup_type]'] option[selected][value='call']"
    assert_select "input[name='first_step[scheduled_for]'][value='2026-10-07T10:00'][required]"

    post "/forefront/leads", params: { lead: lead_params, first_step: first_step(scheduled_for: "2026-10-08T11:00") }

    lead = Forefront::Lead.find_by!(title: "Big Deal")
    followup = lead.followups.sole
    assert_equal [ "call", Time.zone.local(2026, 10, 8, 11), @rep, @rep, "pending" ],
                 [ followup.followup_type, followup.scheduled_for, followup.assigned_to, followup.created_by, followup.status ]
    get "/forefront/leads/#{lead.id}"
    assert_select "[data-next-step]", text: /Next: call Acme on 8 Oct 11:00/
  end

  test "a lead for someone needs a first step; one for the pool gets it when taken" do
    sign_in_as(@rep)
    post "/forefront/leads", params: { lead: lead_params, first_step: first_step(scheduled_for: "") }
    assert_response :unprocessable_entity
    assert_match "First step can&#39;t be blank", response.body
    assert_nil Forefront::Lead.find_by(title: "Big Deal")

    sign_in_as(@admin)
    get "/forefront/leads/new"
    assert_select "input[name='first_step[scheduled_for]']:not([required])"
    post "/forefront/leads", params: { lead: lead_params(assigned_to_id: ""), first_step: first_step(scheduled_for: "") }
    lead = Forefront::Lead.find_by!(title: "Big Deal")
    assert_nil lead.assigned_to
    assert lead.needs_next_step?

    sign_in_as(@rep)
    post "/forefront/leads/#{lead.id}/take"
    follow_redirect!
    assert_select "[data-next-step]", text: /Needs a next step/
    assert_select "[data-next-step] button", text: "Schedule it"
  end

  test "converting a ticket asks for the first step too" do
    ticket = Forefront::Ticket.create!(title: "Enquiry", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.current + 3)
    sign_in_as(@rep)
    get "/forefront/tickets/#{ticket.id}"
    assert_select "form[action='/forefront/tickets/#{ticket.id}/conversion'] select[name='first_step[followup_type]']"

    post "/forefront/tickets/#{ticket.id}/conversion", params: { lead: { title: "Acme deal", source_id: forefront_source.id, due_at: "2026-10-20" }, first_step: first_step }

    lead = Forefront::Lead.find_by!(title: "Acme deal")
    assert_equal Time.zone.local(2026, 10, 7, 10), lead.followups.sole.scheduled_for
  end

  test "an open demo ticket under the lead is its next step when no followup is pending" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "contacted", due_at: Date.current + 10)
    sign_in_as(@rep)
    post "/forefront/leads/#{lead.id}/status_histories", params: { status_history: { status: "demo", ticket_due_at: "2026-10-09" } }

    get "/forefront/leads/#{lead.id}"
    assert_select "[data-next-step]", text: /Next: Schedule demo, due 9 Oct/
    assert_not lead.reload.needs_next_step?
  end

  test "leads needing a next step are flagged on My work and the dashboard" do
    needs = Forefront::Lead.create!(title: "Forgotten", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                    product: @product, status: "contacted", due_at: Date.current + 10)
    fine = Forefront::Lead.create!(title: "Planned", description: "D", customer: Forefront::Customer.create!(name: "Globex", phone: "555-0199"),
                                   created_by: @rep, assigned_to: @rep, source: forefront_source, product: @product, status: "open", due_at: Date.current + 10)
    fine.followups.create!(followup_type: "call", scheduled_for: 1.day.from_now, assigned_to: @rep, created_by: @rep)
    sign_in_as(@rep)

    get "/forefront/my_work"
    assert section("needs_next_step").any? { |row| row.start_with?("Forgotten") }
    assert_not_includes section("needs_next_step").join, "Planned"

    get "/forefront/"
    assert_equal "1", metric(:needs_next_step)
    rows = drill(:needs_next_step)
    assert_equal 1, rows.size
    assert rows.first.start_with?(needs.title)
  end

  test "a ticket's next step is its pending followup, or else its due date" do
    ticket = Forefront::Ticket.create!(title: "Call Acme", description: "D", customer: @customer, product: @product, created_by: @rep, assigned_to: @rep,
                                       category: "enquiry", priority: "medium", status: "open", due_at: Date.new(2026, 10, 9))
    sign_in_as(@rep)
    get "/forefront/tickets/#{ticket.id}"
    assert_select "[data-next-step]", text: /Next: resolve by 9 Oct/

    post "/forefront/tickets/#{ticket.id}/followups", params: { followup: { followup_type: "email", scheduled_for: "2026-10-07T15:00" } }
    get "/forefront/tickets/#{ticket.id}"
    assert_select "[data-next-step]", text: /Next: email Acme on 7 Oct 15:00/
  end

  def section(name)
    css_select("[data-section='#{name}'] li").map { |item| item.text.squish }
  end
end
