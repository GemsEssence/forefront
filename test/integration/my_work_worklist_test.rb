require "test_helper"

# My work is the Sales person's worklist: Overdue and Today first, each row
# saying what to do (the next step), for whom, by when, and what was last
# done, with Done right there.
class Forefront::MyWorkWorklistTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = forefront_product(allocated_to: @rep)
    @customer = Forefront::Customer.create!(name: "Acme", country_code: "+91", phone: "9876543210")
    travel_to Time.zone.local(2026, 10, 6, 9)
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                    product: @product, status: "proposal", due_at: Date.new(2026, 10, 20))
    @late = @lead.followups.create!(followup_type: "call", scheduled_for: Time.zone.local(2026, 10, 5, 15), assigned_to: @rep, created_by: @rep, outcome: "Ask about seats")
    Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: @lead, audited_changes: { "body" => [ nil, "Sent the deck" ] })
    @ticket = Forefront::Ticket.create!(title: "Call Globex", description: "D", customer: Forefront::Customer.create!(name: "Globex", phone: "555-0199"),
                                        product: @product, created_by: @rep, assigned_to: @rep, category: "enquiry", priority: "medium", status: "open", due_at: Date.new(2026, 10, 6))
    sign_in_as(@rep)
  end

  def rows(section)
    css_select("[data-section='#{section}'] li[data-row]")
  end

  test "an overdue followup row says what to do, for whom, by when, what was last done, and offers Done" do
    get "/forefront/my_work"

    row = rows("overdue").sole
    text = row.text.squish
    assert_match "Big Deal", text
    assert_match "Acme", text
    assert_match "Proposal", text
    assert_match(/Next: call .*5 Oct 15:00/, text)
    assert_match "Ask about seats", text
    assert_match(/Deadline 20 Oct/, text)
    assert_match(/Last: added activity/, text)
    assert_select row, "button", text: "Done"
    assert_select row, "form[action='/forefront/followups/#{@late.id}/completion']"
    assert_select row, "a[href='/forefront/leads/#{@lead.id}']", text: /Big Deal/
  end

  test "a ticket due today is a row with its status and Open link; the phone is masked with a reveal button" do
    get "/forefront/my_work"

    row = rows("today").sole
    text = row.text.squish
    assert_match "Call Globex", text
    assert_match "Globex", text
    assert_match "Open", text
    assert_match(/Next: resolve by 6 Oct/, text)
    assert_select row, "form[action='/forefront/customers/#{@ticket.customer.id}/contact_reveal'] button", text: "Show contact details"
    assert_no_match "555-0199", text
  end

  test "Done from the worklist records the outcome and the next step and comes back to the list" do
    post "/forefront/followups/#{@late.id}/completion",
         params: { completion: { outcome: "Agreed 20 seats", next: "followup", followup_type: "email", scheduled_for: "2026-10-08T10:00" } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/my_work" }

    assert_redirected_to "/forefront/my_work"
    assert @late.reload.completed?
    get "/forefront/my_work"
    assert_empty rows("overdue")
    assert_match(/Next: email Acme on 8 Oct 10:00/, rows("next_7_days").sole.text.squish)
  end

  test "sections run Overdue, Today, Needs a next step, then the rest folded away" do
    get "/forefront/my_work"

    assert_equal %w[overdue today needs_next_step next_7_days undated available reveals], css_select("[data-section]").map { |s| s["data-section"] }
    assert_select "details[data-section='next_7_days']"
    assert_select "details[data-section='undated']"
  end
end
