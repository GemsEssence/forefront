require "test_helper"

# Required fields are marked with a red asterisk by a CSS rule on the label
# (see forefront/application.css): a label directly followed by a [required]
# control, or by a wrapper containing one. These tests keep that working by
# checking that each form's required fields carry `required`, and that every
# `required` control sits where the rule can find its label.
class Forefront::RequiredFieldIndicatorTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "the stylesheet marks labels of required controls" do
    css = Forefront::Engine.root.join("app/assets/stylesheets/forefront/application.css").read
    assert_match(/label:has\(\+ \[required\]\)/, css)
    assert_match(/label:has\(\+ \* \[required\]\)/, css)
  end

  {
    "/forefront/tickets/new" => %w[ticket_title ticket_description ticket_customer_id ticket_category ticket_priority ticket_due_at],
    "/forefront/leads/new" => %w[lead_title lead_description lead_customer_id lead_source_id lead_product_id lead_due_at],
    "/forefront/customers/new" => %w[customer_name],
    "/forefront/products/new" => %w[product_name],
    "/forefront/targets/new" => %w[target_admin_id target_product_id target_metric target_goal_value target_period target_starts_on],
    "/forefront/staff/new" => %w[admin_name admin_email admin_password admin_password_confirmation admin_role],
    "/forefront/admins/edit" => %w[admin_name admin_email admin_current_password]
  }.each do |path, required_ids|
    test "#{path} marks its required fields" do
      assert_required_fields(path, required_ids)
    end
  end

  def as_assignee
    rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: rep.email, password: "password123" } }
    rep
  end

  test "the ticket page's modals and activity form mark their required fields" do
    rep = as_assignee
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, assigned_to: rep, category: "new_app_demo", priority: "medium")

    assert_required_fields("/forefront/tickets/#{ticket.id}",
                           %w[status_history_status assignment_to_user_id followup_followup_type followup_scheduled_for])
  end

  test "the payment form marks its required fields" do
    rep = as_assignee
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: rep, source: forefront_source)
    lead.update!(status: "won", actual_amount: 100)

    assert_required_fields("/forefront/leads/#{lead.id}/payment/new", %w[payment_total_amount])
  end

  private

  def assert_required_fields(path, required_ids)
    get path
    assert_response :success
    page = Nokogiri::HTML(response.body)

    required_ids.each do |id|
      control = page.at_css("##{id}")
      assert control, "#{path}: expected a ##{id} field"
      assert control.key?("required"), "#{path}: ##{id} should be required"
    end

    page.css("[required]").each do |control|
      assert marked_by_stylesheet?(control), "#{path}: the label for #{control['name']} won't get the required marker"
    end
  end

  def marked_by_stylesheet?(control)
    control.previous_element&.name == "label" || control.parent.previous_element&.name == "label"
  end
end
