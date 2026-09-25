require "test_helper"

class Forefront::ActivityManagementTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "Demo", description: "Wants a demo", customer: @customer, created_by: @admin, category: "demo", priority: "medium")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "adding the first activity to a ticket renders the turbo stream" do
    post "/forefront/tickets/#{@ticket.id}/activities",
         params: { activity: { activity_type: "comment", body: "Called the customer" } },
         as: :turbo_stream

    assert_response :success
    assert_equal 1, @ticket.activities.count
    assert_includes response.body, "Called the customer"
  end

  test "adding a later activity updates every tab counter" do
    @ticket.activities.create!(activity_type: "comment", body: "First", created_by: @admin)

    post "/forefront/tickets/#{@ticket.id}/activities",
         params: { activity: { activity_type: "internal_note", body: "Second" } },
         as: :turbo_stream

    assert_response :success
    assert_includes response.body, %(target="tab_internal_notes_#{@ticket.id}")
  end

  test "deleting an activity renders the turbo stream" do
    activity = @ticket.activities.create!(activity_type: "comment", body: "First", created_by: @admin)

    delete "/forefront/tickets/#{@ticket.id}/activities/#{activity.id}", as: :turbo_stream

    assert_response :success
    assert_equal 0, @ticket.activities.count
  end
end
