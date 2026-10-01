require "test_helper"

class Forefront::LeadLostTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "proposal")
    @price = Forefront::LostReason.create!(name: "Price")
    @retired = Forefront::LostReason.create!(name: "Retired reason", active: false)
    sign_in_as(@admin)
  end

  # As the browser sends it: the dialog submits through Turbo, which re-renders
  # the dialog with its errors when the change is refused.
  def lose(reason_id:, note:)
    post "/forefront/leads/#{@lead.id}/status_histories",
         params: { status_history: { status: "lost", lost_reason_id: reason_id, note: note } },
         headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  test "losing a lead records the reason and the note, and the lead page shows them" do
    lose(reason_id: @price.id, note: "Went with a cheaper local vendor")

    assert @lead.reload.lost?
    get "/forefront/leads/#{@lead.id}"
    assert_match "Price", response.body
    assert_match "Went with a cheaper local vendor", response.body
  end

  test "a lead can't be lost without a reason" do
    lose(reason_id: "", note: "They stopped replying")

    assert @lead.reload.proposal?
    assert_match "Lost reason must be chosen", response.body
  end

  test "a lead can't be lost without a note, even with a reason" do
    lose(reason_id: @price.id, note: "")

    assert @lead.reload.proposal?
    assert_match "Note is required when a lead is lost", response.body
  end

  test "a deactivated reason can't be chosen" do
    lose(reason_id: @retired.id, note: "Old habit")

    assert @lead.reload.proposal?
    assert_match "Lost reason is no longer in use", response.body
  end

  test "the stage dialog offers only active lost reasons" do
    get "/forefront/leads/#{@lead.id}"

    assert_select "select[name='status_history[lost_reason_id]'] option", text: "Price"
    assert_select "select[name='status_history[lost_reason_id]'] option", text: "Retired reason", count: 0
  end

  test "a lost reason that leads use can't be deleted" do
    lose(reason_id: @price.id, note: "Too dear")

    delete "/forefront/lost_reasons/#{@price.id}"

    assert Forefront::LostReason.exists?(@price.id)
  end
end
