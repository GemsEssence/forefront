require "test_helper"
require "csv"

module AuditLogTestSetup
  extend ActiveSupport::Concern

  included do
    setup do
      @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
      @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
      @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    end
  end

  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end
end

class Forefront::AuditLogTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  test "creating a lead shows up in the audit log for an admin" do
    sign_in_as(@rep)
    post "/forefront/leads", params: { lead: { title: "Big Deal", description: "D", customer_id: @customer.id, source: "website", status: "open" } }

    sign_in_as(@admin)
    get "/forefront/audit_log"

    assert_response :success
    assert_select "tr", text: /Ravi Rep.*created.*Lead.*Big Deal.*Customer: — → Acme/m
  end

  test "updating a lead records what changed, before and after" do
    lead = Forefront::Lead.create!(title: "Old title", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open")

    sign_in_as(@rep)
    patch "/forefront/leads/#{lead.id}", params: { lead: { title: "New title" } }

    sign_in_as(@admin)
    get "/forefront/audit_log"

    assert_select "tr", text: /Ravi Rep.*updated.*Lead.*New title.*Title: Old title → New title/m
  end

  test "deleting a lead is still readable in the log after the lead is gone" do
    lead = Forefront::Lead.create!(title: "Doomed", description: "D", customer: @customer, created_by: @rep, source: "website", status: "open")

    sign_in_as(@admin)
    delete "/forefront/leads/#{lead.id}"
    get "/forefront/audit_log"

    assert_select "tr", text: /Asha Admin.*deleted.*Lead.*Doomed/m
  end

  test "a sales person can't open the audit log" do
    sign_in_as(@rep)
    get "/forefront/audit_log"

    assert_redirected_to "/forefront/"
    assert_match "not authorized", flash[:alert]
  end

  test "creating, updating and deleting a ticket are all recorded" do
    sign_in_as(@admin)
    post "/forefront/tickets", params: { ticket: { title: "Call back", description: "D", customer_id: @customer.id, category: "demo", priority: "high", status: "open" } }
    ticket = Forefront::Ticket.find_by!(title: "Call back")
    patch "/forefront/tickets/#{ticket.id}", params: { ticket: { priority: "low" } }
    delete "/forefront/tickets/#{ticket.id}"

    get "/forefront/audit_log"

    assert_select "tr", text: /created.*Ticket.*Call back/m
    assert_select "tr", text: /updated.*Ticket.*Call back.*Priority: high → low/m
    assert_select "tr", text: /deleted.*Ticket.*Call back/m
  end

  test "creating, updating and deleting a customer are all recorded" do
    sign_in_as(@admin)
    post "/forefront/customers", params: { customer: { name: "Globex", phone: "555-0199" } }
    customer = Forefront::Customer.find_by!(name: "Globex")
    patch "/forefront/customers/#{customer.id}", params: { customer: { business_name: "Globex Corp" } }
    delete "/forefront/customers/#{customer.id}"

    get "/forefront/audit_log"

    assert_select "tr", text: /Asha Admin.*created.*Customer.*Globex/m
    assert_select "tr", text: /updated.*Customer.*Globex.*Business name: — → Globex Corp/m
    assert_select "tr", text: /deleted.*Customer.*Globex/m
  end
end

class Forefront::AuditLogWorkOnALeadTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    @other_rep = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open")
    sign_in_as(@rep)
  end

  def log_row(pattern)
    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_select "tr", text: pattern
  end

  test "adding, editing and deleting an activity are recorded against the lead" do
    post "/forefront/leads/#{@lead.id}/activities", params: { activity: { activity_type: "comment", body: "Spoke to them" } }
    activity = @lead.activities.last
    patch "/forefront/leads/#{@lead.id}/activities/#{activity.id}", params: { activity: { body: "Spoke to the CTO" } }
    delete "/forefront/leads/#{@lead.id}/activities/#{activity.id}"

    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*added activity.*Lead.*Big Deal.*Body: — → Spoke to them/m
    assert_select "tr", text: /Ravi Rep.*edited activity.*Lead.*Big Deal.*Body: Spoke to them → Spoke to the CTO/m
    assert_select "tr", text: /Ravi Rep.*deleted activity.*Lead.*Big Deal.*Body: Spoke to the CTO → —/m
  end

  test "scheduling and completing a followup are recorded against the lead" do
    post "/forefront/leads/#{@lead.id}/followups", params: { followup: { followup_type: "call", scheduled_for: 2.days.from_now } }
    followup = @lead.followups.last
    patch "/forefront/leads/#{@lead.id}/followups/#{followup.id}", params: { followup: { status: "completed" } }

    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*scheduled followup.*Lead.*Big Deal/m
    assert_select "tr", text: /Ravi Rep.*updated followup.*Lead.*Big Deal.*Status: pending → completed/m
  end

  test "reassigning a lead records who it moved from and to" do
    post "/forefront/leads/#{@lead.id}/assignments", params: { assignment: { to_user_id: @other_rep.id } }

    log_row(/Ravi Rep.*assigned.*Lead.*Big Deal.*Assigned to: Ravi Rep → Meera Rep/m)
  end

  test "changing a lead's status records the old and new status" do
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "proposal" } }

    log_row(/Ravi Rep.*changed status.*Lead.*Big Deal.*Status: open → proposal/m)
  end
end

class Forefront::AuditLogMoneyTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "won", actual_amount: 300)
    sign_in_as(@rep)
  end

  test "recording a payment, its installments and marking them paid are recorded against the lead" do
    post "/forefront/leads/#{@lead.id}/payment", params: { payment: { total_amount: "300" } }
    post "/forefront/leads/#{@lead.id}/payment/installments", params: { installment: { amount: "150", due_on: "2026-11-20" } }
    installment = @lead.reload.payment.installments.last
    patch "/forefront/leads/#{@lead.id}/payment/installments/#{installment.id}"
    patch "/forefront/leads/#{@lead.id}/payment"

    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*recorded payment.*Lead.*Big Deal.*Total amount: — → 300/m
    assert_select "tr", text: /Ravi Rep.*added installment.*Lead.*Big Deal.*Amount: — → 150.*Due on: — → 2026-11-20/m
    assert_select "tr", text: /Ravi Rep.*marked installment paid.*Lead.*Big Deal.*Status: pending → paid/m
    assert_select "tr", text: /Ravi Rep.*marked payment paid.*Lead.*Big Deal.*Status: pending → paid/m
  end

  test "recording a lead share lists each person's percentage" do
    meera = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @lead.assignments.create!(to_user: meera, changed_by: @admin)
    post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @rep.id => "40", meera.id => "60" } } }

    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*recorded lead share.*Lead.*Big Deal.*Shares: — → (Ravi Rep 40%, Meera Rep 60%|Meera Rep 60%, Ravi Rep 40%)/m
  end
end

class Forefront::AuditLogSetupRecordsTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    @product = Forefront::Product.create!(name: "Widget")
    sign_in_as(@admin)
  end

  test "creating and editing staff is recorded without their password" do
    post "/forefront/staff", params: { admin: { name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", role: "sales_person", product_ids: [ @product.id ] } }
    meera = Forefront::Admin.find_by!(name: "Meera Rep")
    patch "/forefront/staff/#{meera.id}", params: { admin: { role: "manager", password: "newpassword1", password_confirmation: "newpassword1" } }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*created.*Staff.*Meera Rep.*Role: — → sales_person.*Products: — → Widget/m
    assert_select "tr", text: /Asha Admin.*updated.*Staff.*Meera Rep.*Role: sales_person → manager.*Password: — → changed/m
    assert_no_match meera.reload.encrypted_password, response.body
  end

  test "creating a product and changing who it's allocated to are recorded" do
    post "/forefront/products", params: { product: { name: "Gadget", description: "A thing", admin_ids: [ @rep.id.to_s ] } }
    gadget = Forefront::Product.find_by!(name: "Gadget")
    patch "/forefront/products/#{gadget.id}", params: { product: { name: "Gadget Pro", admin_ids: [ "" ] } }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*created.*Product.*Gadget.*Allocated to: — → Ravi Rep/m
    assert_select "tr", text: /Asha Admin.*updated.*Product.*Gadget Pro.*Name: Gadget → Gadget Pro.*Allocated to: Ravi Rep → —/m
  end

  test "setting and changing a target are recorded" do
    post "/forefront/targets", params: { target: { admin_id: @rep.id, product_id: @product.id, metric: "amount", goal_value: "1000", period: "monthly", starts_on: "2026-10-01" } }
    target = Forefront::Target.last
    patch "/forefront/targets/#{target.id}", params: { target: { goal_value: "1500" } }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*created.*Target.*Ravi Rep · Widget.*Goal value: — → 1000/m
    assert_select "tr", text: /Asha Admin.*updated.*Target.*Ravi Rep · Widget.*Goal value: 1000.0 → 1500/m
  end
end

class Forefront::AuditLogManagerTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep.update!(manager: @manager)
    @outsider = Forefront::Admin.create!(name: "Otto Outsider", email: "otto-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
  end

  test "a manager sees what they and their team did, and nobody else" do
    { @rep => "Team Lead", @manager => "Manager Lead", @outsider => "Outsider Lead", @admin => "Admin Lead" }.each do |staff, title|
      Forefront::AuditEvent.record!(actor: staff, action: "created",
        auditable: Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: staff, source: "website", status: "open"))
    end

    sign_in_as(@manager)
    get "/forefront/audit_log"

    assert_response :success
    assert_match "Team Lead", response.body
    assert_match "Manager Lead", response.body
    assert_no_match "Outsider Lead", response.body
    assert_no_match "Admin Lead", response.body
  end

  test "a manager doesn't see customer contact details through the log, but an admin does" do
    sign_in_as(@rep)
    post "/forefront/customers", params: { customer: { name: "Globex", email: "boss@globex.example", phone: "555-0199" } }

    sign_in_as(@manager)
    get "/forefront/audit_log"
    assert_select "tr", text: /created.*Customer.*Globex.*Email: — → hidden.*Phone: — → hidden/m
    assert_no_match "boss@globex.example", response.body
    assert_no_match "555-0199", response.body

    sign_in_as(@admin)
    get "/forefront/audit_log"
    assert_match "boss@globex.example", response.body
  end
end

class Forefront::AuditLogFilterTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, source: "website", status: "open")
    travel_to Time.zone.local(2026, 9, 10, 12) do
      Forefront::AuditEvent.record!(actor: @rep, action: "created", auditable: lead)
    end
    travel_to Time.zone.local(2026, 9, 20, 12) do
      Forefront::AuditEvent.record!(actor: @admin, action: "updated", auditable: @customer, audited_changes: { "name" => [ "Acme", "Acme Ltd" ] })
    end
    sign_in_as(@admin)
  end

  def rows
    css_select("tbody tr").map { |row| row.text.squish }
  end

  test "filters by who did it" do
    get "/forefront/audit_log", params: { actor_id: @rep.id }

    assert_equal 1, rows.size
    assert_match "Big Deal", rows.first
  end

  test "filters by record type and by action" do
    get "/forefront/audit_log", params: { auditable_type: "Forefront::Customer" }
    assert_equal 1, rows.size
    assert_match "Acme", rows.first

    get "/forefront/audit_log", params: { event_action: "created" }
    assert_equal 1, rows.size
    assert_match "Big Deal", rows.first
  end

  test "filters by date range, including the whole of the last day" do
    get "/forefront/audit_log", params: { from: "2026-09-15", to: "2026-09-20" }
    assert_equal 1, rows.size
    assert_match "Acme", rows.first

    get "/forefront/audit_log", params: { from: "2026-09-01", to: "2026-09-10" }
    assert_equal 1, rows.size
    assert_match "Big Deal", rows.first
  end

  test "the page offers a filter form with the staff, record types and actions in the log" do
    get "/forefront/audit_log"

    assert_select "form select[name=actor_id] option", text: "Ravi Rep"
    assert_select "form select[name=auditable_type] option", text: "Customer"
    assert_select "form select[name=event_action] option", text: "updated"
    assert_select "form input[type=date][name=from]"
  end
end

class Forefront::AuditLogCsvTest < ActionDispatch::IntegrationTest
  include AuditLogTestSetup

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep.update!(manager: @manager)
    Forefront::AuditEvent.record!(actor: @rep, action: "updated", auditable: @customer, audited_changes: { "phone" => [ "555-0100", "555-0111" ] })
    Forefront::AuditEvent.record!(actor: @admin, action: "updated", auditable: @customer, audited_changes: { "name" => [ "Acme", "Acme Ltd" ] })
  end

  test "an admin downloads the filtered log as CSV" do
    sign_in_as(@admin)
    get "/forefront/audit_log.csv", params: { actor_id: @rep.id }

    assert_response :success
    assert_equal "text/csv", response.media_type
    csv = CSV.parse(response.body, headers: true)
    assert_equal [ "When", "Who", "Action", "Record type", "Record", "Changes" ], csv.headers
    assert_equal 1, csv.size
    assert_equal "Ravi Rep", csv[0]["Who"]
    assert_equal "Phone: 555-0100 → 555-0111", csv[0]["Changes"]
  end

  test "a manager's CSV holds only their team's events, with contact details hidden" do
    sign_in_as(@manager)
    get "/forefront/audit_log.csv"

    csv = CSV.parse(response.body, headers: true)
    assert_equal [ "Ravi Rep" ], csv.map { |row| row["Who"] }
    assert_equal "Phone: hidden → hidden", csv[0]["Changes"]
    assert_no_match "555-01", response.body
  end

  test "the log page links to the CSV of what it's showing" do
    sign_in_as(@admin)
    get "/forefront/audit_log", params: { actor_id: @rep.id }

    assert_select "a[href=?]", "/forefront/audit_log.csv?actor_id=#{@rep.id}", text: "Export CSV"
  end
end
