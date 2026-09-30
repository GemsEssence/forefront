require "test_helper"

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
    assert_select "tr", text: /Ravi Rep.*created.*Lead.*Big Deal/m
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
