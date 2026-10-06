require "test_helper"

# Drives the Change Status / Change Assignee / Schedule Followup modals using the
# field names the show page actually renders, so a mismatch between the form and
# the controller's strong params can't hide behind hand-written params.
class Forefront::TicketModalActionsTest < ActionDispatch::IntegrationTest
  setup do
    @email = "alice-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: @email, password: "password123", role: "sales_person")
    @rep = Forefront::Admin.create!(name: "Rita", email: "rita-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "Demo", description: "Wants a demo", customer: @customer, created_by: @admin, assigned_to: @admin, category: "new_app_demo", priority: "medium")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "changing status through the modal records the transition" do
    fields = modal_field_names("status_history_modal_ticket_#{@ticket.id}")

    post "/forefront/tickets/#{@ticket.id}/status_histories",
         params: form_params(fields, "status" => "in_progress", "note" => "Started work"),
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@ticket.id}" }

    assert_redirected_to "/forefront/tickets/#{@ticket.id}"
    assert @ticket.reload.in_progress?
    history = @ticket.status_histories.last
    assert_equal [ "Open", "In Progress", "Started work" ], [ history.old_status, history.new_status, history.note ]
    assert_equal @admin, history.changed_by
  end

  test "changing assignee through the modal reassigns the ticket" do
    fields = modal_field_names("assignment_modal_ticket_#{@ticket.id}")

    post "/forefront/tickets/#{@ticket.id}/assignments",
         params: form_params(fields, "to_user_id" => @rep.id, "note" => "Over to Rita"),
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@ticket.id}" }

    assert_redirected_to "/forefront/tickets/#{@ticket.id}"
    assert_nil flash[:alert]
    assert_equal @rep, @ticket.reload.assigned_to
    assert_equal "Over to Rita", @ticket.assignments.last.note
  end

  test "scheduling a followup through the modal creates it" do
    fields = modal_field_names("followup_modal_ticket_#{@ticket.id}")

    post "/forefront/tickets/#{@ticket.id}/followups",
         params: form_params(fields, "followup_type" => "call", "assigned_to_id" => @rep.id,
                                     "scheduled_for" => 1.day.from_now.strftime("%Y-%m-%dT%H:%M")),
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@ticket.id}" }

    assert_redirected_to "/forefront/tickets/#{@ticket.id}"
    assert_equal 1, @ticket.followups.count
  end

  test "an invalid status change redirects back with the error" do
    post "/forefront/tickets/#{@ticket.id}/status_histories",
         params: { status_history: { status: "" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@ticket.id}" }

    assert_redirected_to "/forefront/tickets/#{@ticket.id}"
    assert flash[:alert].present?
    assert @ticket.reload.open?
  end

  private

  # Returns { "status" => "status_history[status]", ... } for the named modal's inputs.
  def modal_field_names(modal_id)
    get "/forefront/tickets/#{@ticket.id}"
    assert_response :success
    modal = Nokogiri::HTML(response.body).at_css("##{modal_id}")
    assert modal, "expected the show page to render ##{modal_id}"

    modal.css("input[name], select[name], textarea[name]").map { |el| el["name"] }
         .reject { |name| %w[authenticity_token _method].include?(name) }
         .index_by { |name| name[/\[(\w+)\]\z/, 1] || name }
  end

  def form_params(fields, values)
    values.each_with_object({}) do |(key, value), params|
      name = fields.fetch(key) { flunk "modal has no #{key} field (has: #{fields.keys.join(', ')})" }
      Rack::Utils.parse_nested_query("#{name}=#{CGI.escape(value.to_s)}").deep_merge!(params)
               .then { |merged| params.replace(merged) }
    end
  end
end
