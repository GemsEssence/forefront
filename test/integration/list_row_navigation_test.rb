require "test_helper"

# Index lists live inside a turbo frame so the filter form can refresh them in
# place. Links inside that frame (row → show page) must break out of it, or
# Turbo looks for a matching frame on the show page and renders "Content missing".
class Forefront::ListRowNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    Forefront::Ticket.create!(title: "Demo", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium")
    Forefront::Lead.create!(title: "Prospect", description: "D", customer: @customer, created_by: @admin, source: forefront_source)

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  %w[tickets leads customers].each do |list|
    test "#{list} list frame navigates the whole page" do
      get "/forefront/#{list}"
      assert_response :success

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame##{list}_list")
      assert frame, "expected a ##{list}_list turbo frame"
      assert_equal "_top", frame["target"]
    end
  end
end
