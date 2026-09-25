require "test_helper"

# Turbo only prompts before submitting a form carrying data-turbo-confirm;
# rails-ujs's data-confirm is ignored, so Delete would fire with no prompt.
class Forefront::DeleteConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "demo", priority: "medium")
    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website")
    @ticket.activities.create!(activity_type: "comment", body: "Hi", created_by: @admin)

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "every delete form on the ticket, lead and customer pages asks for confirmation" do
    [ "/forefront/tickets/#{@ticket.id}", "/forefront/leads/#{@lead.id}", "/forefront/customers/#{@customer.id}" ].each do |path|
      get path
      delete_forms = Nokogiri::HTML(response.body).css("form").select { |form| form.at_css("input[name=_method][value=delete]") }
                                                    .reject { |form| form["action"].end_with?("/sign_out") }

      assert delete_forms.any?, "#{path}: expected a delete form"
      delete_forms.each do |form|
        assert form["data-turbo-confirm"].present?, "#{path}: delete form for #{form['action']} has no data-turbo-confirm"
      end
    end
  end
end
