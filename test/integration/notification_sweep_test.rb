require "test_helper"
require "rake"

class Forefront::NotificationSweepTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_manager = Forefront::Admin.create!(name: "Omar Manager", email: "omar-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @customer = Forefront::Customer.create!(name: "Priya Shah", email: "priya@gmail.com", country_code: "+91", phone: "9876543210")
  end

  def sweep
    Forefront::NotificationSweepJob.perform_now
  end

  def messages_for(admin)
    sign_in_as(admin)
    get "/forefront/notifications"
    css_select("li a").map { |link| link.text.squish }
  end

  def unassigned_ticket(created_at:)
    Forefront::Ticket.create!(title: "Schedule a call", description: "D", customer: @customer, created_by: @admin,
                              category: "signup", priority: "high", status: "open", created_at: created_at)
  end

  test "work still unassigned after the limit alerts managers and admins, once" do
    unassigned_ticket(created_at: 3.hours.ago)
    unassigned_ticket(created_at: 1.hour.ago).update!(title: "Too new")

    sweep
    sweep

    assert_equal [ "Still unassigned after 2 hours: Schedule a call" ], messages_for(@manager)
    assert_includes messages_for(@admin), "Still unassigned after 2 hours: Schedule a call"
    assert_empty messages_for(@rep)
  end

  test "the unassigned limit comes from the settings" do
    Forefront::Settings.current.tap { |s| s.unassigned_alert_after_hours = 4 }.save
    unassigned_ticket(created_at: 3.hours.ago)

    sweep

    assert_empty messages_for(@manager)
  end

  test "a reveal with no action after the limit alerts admins and the revealer's manager" do
    reveal = Forefront::ContactReveal.create!(admin: @rep, customer: @customer, created_at: 61.minutes.ago)
    Forefront::ContactReveal.create!(admin: @rep, customer: @customer, created_at: 10.minutes.ago)

    sweep

    expected = "Ravi Rep revealed Priya Shah's contact details at #{reveal.created_at.strftime("%-d %b %H:%M")} and hasn't recorded what they did"
    assert_equal [ expected ], messages_for(@manager)
    assert_equal [ expected ], messages_for(@admin)
    assert_empty messages_for(@other_manager)
  end

  test "a reveal that's been answered raises nothing" do
    ticket = Forefront::Ticket.create!(title: "Call", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                       category: "request", priority: "medium", status: "open")
    travel_to 2.hours.ago do
      Forefront::ContactReveal.create!(admin: @rep, customer: @customer)
      Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: ticket, audited_changes: {})
    end

    sweep

    assert_empty messages_for(@manager)
  end

  test "an installment unpaid past its due date alerts the lead's assignee" do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, status: "won", actual_amount: 20_000)
    payment = Forefront::Payment.create!(lead: lead, total_amount: 20_000)
    payment.installments.create!(amount: 10_000, due_on: 2.days.ago.to_date)
    payment.installments.create!(amount: 10_000, due_on: Date.current)

    sweep

    assert_equal [ "Installment of ₹10,000.00 due #{2.days.ago.to_date.strftime("%-d %b")} on Big Deal is unpaid" ], messages_for(@rep)
  end

  test "the rake task runs the same check" do
    unassigned_ticket(created_at: 3.hours.ago)
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "forefront:notify" }

    Rake::Task["forefront:notify"].execute

    assert_equal 1, messages_for(@manager).size
  end
end
