require "test_helper"

class Forefront::StaleWorkTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def sweep
    Forefront::NotificationSweepJob.perform_now
  end

  def messages_for(admin)
    sign_in_as(admin)
    get "/forefront/notifications"
    css_select("li a").map { |link| link.text.squish }
  end

  # Assigned to Ravi `ago`, the way Forefront records it.
  def assigned_ticket(ago:, **attributes)
    travel_to(ago.ago) do
      ticket = Forefront::Ticket.create!({ title: "Call Acme", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                           category: "request", priority: "medium", status: "open" }.merge(attributes))
      ticket.assignments.create!(to_user: @rep, changed_by: @rep)
      Forefront::AuditEvent.record!(actor: @rep, action: "created", auditable: ticket)
      ticket
    end
  end

  def act_on(record, ago:)
    travel_to(ago.ago) { Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: record, audited_changes: {}) }
  end

  test "assigned work with no action for the limit alerts its assignee and their manager, once" do
    assigned_ticket(ago: 25.hours)

    sweep
    sweep

    assert_equal [ "No action on Call Acme for 24 hours" ], messages_for(@rep)
    assert_equal [ "No action on Call Acme for 24 hours" ], messages_for(@manager)
  end

  test "a recent action keeps it from being stale" do
    ticket = assigned_ticket(ago: 30.hours)
    act_on(ticket, ago: 2.hours)

    sweep

    assert_empty messages_for(@rep)
  end

  test "it goes stale again if the next action doesn't come" do
    ticket = assigned_ticket(ago: 60.hours)
    sweep
    act_on(ticket, ago: 30.hours)

    sweep

    assert_equal 2, messages_for(@rep).size
  end

  test "work past its due date with no action since is stale" do
    Forefront::Settings.current.tap { |settings| settings.stale_after_hours = 100 }.save
    ticket = assigned_ticket(ago: 4.days, due_at: 2.days.ago.to_date)
    act_on(ticket, ago: 3.days)

    sweep

    assert_equal [ "Call Acme was due #{2.days.ago.to_date.strftime("%-d %b")} with no action since" ], messages_for(@rep)
  end

  test "a lead waiting on the customer isn't stale until its followup is overdue" do
    lead = travel_to(30.hours.ago) do
      Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                              source: forefront_source, status: "demo").tap { |created| created.update!(awaiting_customer_since: Time.current) }
    end
    followup = lead.followups.create!(assigned_to: @rep, created_by: @rep, followup_type: "call", scheduled_for: 1.day.from_now)

    sweep
    assert_empty messages_for(@rep)

    followup.update!(scheduled_for: 1.hour.ago)
    sweep
    assert_equal [ "No action on Big Deal for 24 hours" ], messages_for(@rep)
  end

  test "unassigned or finished work is never stale" do
    assigned_ticket(ago: 30.hours, status: "resolved")
    travel_to(30.hours.ago) do
      Forefront::Ticket.create!(title: "Nobody's", description: "D", customer: @customer, created_by: @manager,
                                category: "request", priority: "medium", status: "open")
    end

    sweep

    assert_empty messages_for(@rep)
    assert_not messages_for(@manager).any? { |message| message.start_with?("No action") }
  end
end
