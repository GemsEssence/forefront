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
end
