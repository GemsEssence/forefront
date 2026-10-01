require "test_helper"

class Forefront::NotificationEmailTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "asha-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def unassigned_ticket(created_at: 3.hours.ago)
    Forefront::Ticket.create!(title: "Schedule a call", description: "D", customer: @customer, created_by: @admin,
                              category: "signup", priority: "high", status: "open", created_at: created_at)
  end

  def sweep
    Forefront::NotificationSweepJob.perform_now
  end

  test "each alert is emailed to its recipient once, with a link to it" do
    unassigned_ticket

    sweep
    sweep

    assert_equal [ @admin.email, @manager.email ].sort, ActionMailer::Base.deliveries.flat_map(&:to).sort
    mail = ActionMailer::Base.deliveries.find { |delivery| delivery.to == [ @manager.email ] }
    assert_equal "Still unassigned after 2 hours: Schedule a call", mail.subject
    notification = Forefront::Notification.find_by!(recipient: @manager)
    assert_match "http://www.example.com/forefront/notifications/#{notification.id}", mail.text_part.body.to_s
    assert_match "http://www.example.com/forefront/notifications/#{notification.id}", mail.html_part.body.to_s
  end

  test "an alert whose email is switched off in the settings stays in Forefront only" do
    Forefront::Settings.current.tap { |settings| settings.email_unassigned = false }.save
    unassigned_ticket

    sweep

    assert_empty ActionMailer::Base.deliveries
    assert Forefront::Notification.exists?(recipient: @manager, kind: "still_unassigned")
  end

  test "the immediate new-unassigned alert isn't emailed; the later one is" do
    key = Forefront::Product.create!(name: "Widget").generate_api_key!
    post "/forefront/api/v1/signup", params: { name: "Priya", phone: "9876543210" }.to_json,
                                     headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{key}" }

    assert_empty ActionMailer::Base.deliveries
  end

  test "emails come from the configured sender" do
    original = Forefront.mailer_sender
    Forefront.mailer_sender = "sales-alerts@acme.example"
    unassigned_ticket

    sweep

    assert_equal [ "sales-alerts@acme.example" ], ActionMailer::Base.deliveries.first.from
  ensure
    Forefront.mailer_sender = original
  end
end
