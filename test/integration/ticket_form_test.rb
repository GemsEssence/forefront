require "test_helper"

class Forefront::TicketFormTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "title and description have visible labels" do
    get "/forefront/tickets/new"
    assert_response :success

    page = Nokogiri::HTML(response.body)
    %w[ticket_title ticket_description].each do |field|
      label = page.at_css("label[for=#{field}]")
      assert label, "expected a label for ##{field}"
      assert_not_includes label["class"].to_s.split, "sr-only", "label for ##{field} is visually hidden"
    end
  end

  test "the assignee list leaves out admins" do
    manager = Forefront::Admin.create!(name: "Max", email: "max-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: customer, created_by: manager, category: "new_app_demo", priority: "medium")

    [ "/forefront/tickets/new", "/forefront/tickets/#{ticket.id}/edit" ].each do |path|
      get path
      options = Nokogiri::HTML(response.body).css("select#ticket_assigned_to_id option").map(&:text)
      assert_includes options, "Max", path
      assert_not_includes options, "Alice", path
    end

    get "/forefront/tickets/#{ticket.id}"
    options = Nokogiri::HTML(response.body).css("#assignment_modal_ticket_#{ticket.id} select option").map(&:text)
    assert_includes options, "Max"
    assert_not_includes options, "Alice"
  end
end
