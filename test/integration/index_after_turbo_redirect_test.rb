require "test_helper"

# When a Turbo form submission (delete, or a modal on an index row) redirects
# to an index page, the followed GET still sends Turbo's turbo-stream Accept
# header. The index must answer with the full HTML page, or Turbo never
# navigates and the flash never shows.
class Forefront::IndexAfterTurboRedirectTest < ActionDispatch::IntegrationTest
  TURBO_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "deleting a ticket from its page lands on the tickets page with the notice" do
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium")

    delete "/forefront/tickets/#{ticket.id}", headers: { "Accept" => TURBO_ACCEPT }
    follow_redirect!(headers: { "Accept" => TURBO_ACCEPT })

    assert_equal "text/html", response.media_type
    assert_includes response.body, "Ticket was successfully deleted."
  end

  %w[tickets leads customers].each do |list|
    test "the #{list} index answers a turbo-stream request with the full page" do
      get "/forefront/#{list}", headers: { "Accept" => TURBO_ACCEPT }

      assert_response :success
      assert_equal "text/html", response.media_type
    end
  end
end
