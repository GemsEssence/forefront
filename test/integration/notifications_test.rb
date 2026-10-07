require "test_helper"

class Forefront::NotificationsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
  end

  def signup
    key = @product.generate_api_key!
    post "/forefront/api/v1/signup", params: { name: "Priya Shah", country_code: "+91", phone: "9876543210" }.to_json,
                                     headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{key}" }
    Forefront::Ticket.last
  end

  def bell
    get "/forefront/"
    css_select("[data-notification-bell]").first&.text&.squish
  end

  test "new unassigned work notifies managers and admins, but not sales persons" do
    ticket = signup

    sign_in_as(@manager)
    assert_equal "Notifications 1", bell
    get "/forefront/notifications"
    assert_select "li", text: /New unassigned ticket: #{Regexp.escape(ticket.title)}/

    sign_in_as(@admin)
    assert_equal "Notifications 1", bell

    sign_in_as(@rep)
    assert_equal "Notifications", bell
  end

  test "opening a notification marks it read and goes to the work" do
    ticket = signup
    sign_in_as(@manager)
    get "/forefront/notifications"
    link = css_select("li a").first["href"]

    get link

    assert_redirected_to "/forefront/tickets/#{ticket.id}"
    assert_equal "Notifications", bell
  end

  test "all notifications can be marked read at once" do
    signup
    sign_in_as(@admin)

    post "/forefront/notifications/read_all"

    assert_equal "Notifications", bell
  end

  test "work created with an assignee notifies nobody" do
    sign_in_as(@rep)
    post "/forefront/tickets", params: { ticket: { source_id: forefront_source.id, title: "Mine", description: "D", customer_id: Forefront::Customer.create!(name: "Acme", phone: "555-0100").id,
                                                   category: "request", priority: "medium", status: "open" } }

    sign_in_as(@manager)
    assert_equal "Notifications", bell
  end

  test "whoever left the work unassigned isn't told about it" do
    other_admin = Forefront::Admin.create!(name: "Arjun Admin", email: "arjun-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
    post "/forefront/tickets", params: { ticket: { source_id: forefront_source.id, title: "For whoever's free", description: "D", customer_id: Forefront::Customer.create!(name: "Acme", phone: "555-0100").id,
                                                   category: "request", priority: "medium", status: "open", assigned_to_id: "" } }

    assert_nil Forefront::Ticket.last.assigned_to
    assert_equal "Notifications", bell
    sign_in_as(other_admin)
    assert_equal "Notifications 1", bell
    sign_in_as(@manager)
    assert_equal "Notifications 1", bell
  end

  test "you can't open someone else's notification" do
    signup
    notification = Forefront::Notification.find_by!(recipient: @admin)
    sign_in_as(@manager)

    get "/forefront/notifications/#{notification.id}"

    assert_response :not_found
    assert_nil notification.reload.read_at
  end
end
