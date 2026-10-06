require "test_helper"

# A modal form that fails validation must show its errors inside the modal
# and stay open, keeping what the user typed, rather than closing and
# flashing the error on the page behind it.
class Forefront::ModalFormErrorsTest < ActionDispatch::IntegrationTest
  setup do
    @email = "rita-#{SecureRandom.hex(4)}@example.com"
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @rep = Forefront::Admin.create!(name: "Rita", email: @email, password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", assigned_to: @rep)
    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, assigned_to: @rep, source: forefront_source, estimated_amount: 500)

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: @email, password: "password123" } }
  end

  test "change status: a lead won without an actual amount keeps the modal open with the error" do
    post "/forefront/leads/#{@lead.id}/status_histories",
         params: { status_history: { status: "won", actual_amount: "", note: "Closed the deal" } }, as: :turbo_stream

    modal = reopened_modal("status_history_modal_lead_#{@lead.id}")
    assert_includes modal.at_css("[role=alert]").text, "Actual amount can't be blank"
    assert_equal "won", modal.at_css("select[name='status_history[status]'] option[selected]")["value"]
    assert_equal "Closed the deal", modal.at_css("textarea[name='status_history[note]']").text.strip
    assert modal.at_css("[data-won-amount]")["style"].to_s.exclude?("display:none"), "the actual amount field should be showing"
    assert_not @lead.reload.won?
  end

  test "change assignee: an invalid assignee keeps the modal open with the error" do
    post "/forefront/tickets/#{@ticket.id}/assignments",
         params: { assignment: { to_user_id: @admin.id, note: "Taking this" } }, as: :turbo_stream

    modal = reopened_modal("assignment_modal_ticket_#{@ticket.id}")
    assert_includes modal.at_css("[role=alert]").text, "Assigned to can't be an admin"
    assert_equal "Taking this", modal.at_css("textarea[name='assignment[note]']").text.strip
    assert_equal @rep, @ticket.reload.assigned_to
  end

  test "add followup: a blank form keeps the modal open with every error" do
    post "/forefront/tickets/#{@ticket.id}/followups",
         params: { followup: { followup_type: "", scheduled_for: "", assigned_to_id: "", outcome: "Call back about pricing" } }, as: :turbo_stream

    modal = reopened_modal("followup_modal_ticket_#{@ticket.id}")
    errors = modal.at_css("[role=alert]").text
    assert_includes errors, "Followup type can't be blank"
    assert_includes errors, "Scheduled for can't be blank"
    assert_equal "Call back about pricing", modal.at_css("textarea[name='followup[outcome]']").text.strip
    assert_equal 0, @ticket.followups.count
  end

  test "edit followup: clearing the time keeps that followup's modal open with the error" do
    followup = @ticket.followups.create!(assigned_to: @rep, created_by: @admin, followup_type: "call", scheduled_for: 1.day.from_now)

    patch "/forefront/tickets/#{@ticket.id}/followups/#{followup.id}",
          params: { followup: { scheduled_for: "", outcome: "Moved" } }, as: :turbo_stream

    modal = reopened_modal("followup_edit_modal_#{followup.id}")
    assert_includes modal.at_css("[role=alert]").text, "Scheduled for can't be blank"
    assert_equal "Moved", modal.at_css("textarea[name='followup[outcome]']").text.strip
    assert followup.reload.scheduled_for.present?
  end

  test "modals render closed and without errors on the page itself" do
    get "/forefront/tickets/#{@ticket.id}"

    page = Nokogiri::HTML(response.body)
    %W[status_history_modal_ticket_#{@ticket.id} assignment_modal_ticket_#{@ticket.id} followup_modal_ticket_#{@ticket.id}].each do |id|
      modal = page.at_css("##{id}")
      assert modal, "expected ##{id}"
      assert_includes modal["style"].to_s, "display:none", "##{id} should start closed"
      assert_nil modal.at_css("[role=alert]")
    end
  end

  test "without Turbo, a failure still redirects back with the error" do
    post "/forefront/tickets/#{@ticket.id}/followups",
         params: { followup: { followup_type: "", scheduled_for: "" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/tickets/#{@ticket.id}" }

    assert_redirected_to "/forefront/tickets/#{@ticket.id}"
    assert_match "Followup type can't be blank", flash[:alert]
  end

  private

  # The turbo-stream response must replace the modal with a copy that is open.
  def reopened_modal(id)
    assert_response :unprocessable_entity
    assert_equal "text/vnd.turbo-stream.html", response.media_type

    stream = Nokogiri::HTML(response.body).at_css("turbo-stream[action=replace][target=#{id}]")
    assert stream, "expected a turbo stream replacing ##{id}"

    modal = Nokogiri::HTML(stream.at_css("template").inner_html).at_css("##{id}")
    assert modal, "the replacement should be the ##{id} modal itself"
    assert modal["style"].to_s.exclude?("display:none"), "##{id} should come back open"
    modal
  end
end
