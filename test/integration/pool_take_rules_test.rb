require "test_helper"

# Who takes from the Unassigned pool (CONTEXT.md): Sales persons for their
# Products, Managers for anything, Admins never. Taking stops at the cap on
# unfinished Leads one person may hold; a Manager assigning past it is fine.
class Forefront::PoolTakeRulesTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @widget = forefront_product(allocated_to: @rep)
    @gadget = forefront_product("Gadget")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @pooled = pool_lead("Gadget deal", @gadget)
  end

  def pool_lead(title, product, customer: nil)
    customer ||= Forefront::Customer.create!(name: "Customer #{SecureRandom.hex(2)}", phone: "555-#{rand(1000..9999)}")
    Forefront::Lead.create!(title: title, description: "D", customer: customer, created_by: @manager, source: forefront_source, product: product, status: "open")
  end

  def held_lead(title, status: "open")
    lead = pool_lead(title, @widget)
    lead.update!(assigned_to: @rep, status: status, actual_amount: (100 if status == "won"),
                 lost_reason: (Forefront::LostReason.find_or_create_by!(name: "Price") if status == "lost"), lost_note: ("No" if status == "lost"))
    lead
  end

  test "a manager takes any lead from the pool, whatever its product" do
    sign_in_as(@manager)
    get "/forefront/unassigned"
    assert_select "form[action='/forefront/leads/#{@pooled.id}/take'] button", text: "Take"

    post "/forefront/leads/#{@pooled.id}/take"

    assert_equal @manager, @pooled.reload.assigned_to
  end

  test "an admin can't take from the pool, only assign" do
    sign_in_as(@admin)
    get "/forefront/unassigned"
    assert_select "form[action='/forefront/leads/#{@pooled.id}/take']", count: 0
    assert_select "a[href='/forefront/leads/#{@pooled.id}']", text: "Assign"

    post "/forefront/leads/#{@pooled.id}/take"

    assert_nil @pooled.reload.assigned_to
    assert_match "not authorized", flash[:alert]
  end

  test "a lead is never assigned to an admin" do
    sign_in_as(@admin)
    get "/forefront/leads/#{@pooled.id}"
    assert_select "select[name='assignment[to_user_id]'] option", text: "Asha Admin", count: 0
    assert_select "select[name='assignment[to_user_id]'] option", text: "Mona Manager"

    post "/forefront/leads/#{@pooled.id}/assignments", params: { assignment: { to_user_id: @admin.id } }

    assert_nil @pooled.reload.assigned_to
  end

  test "a lead an admin creates without an assignee goes to the pool rather than to the admin" do
    sign_in_as(@admin)

    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: "Fresh", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: @widget.id }, first_step: forefront_first_step }

    assert_nil Forefront::Lead.find_by!(title: "Fresh").assigned_to
  end

  test "a sales person at the cap can't take another lead; won and lost ones don't count" do
    Forefront::Setting.create!(key: "lead_cap", value: "2")
    held_lead("One")
    held_lead("Two")
    held_lead("Won", status: "won")
    held_lead("Lost", status: "lost")
    widget_pooled = pool_lead("Widget deal", @widget)
    sign_in_as(@rep)

    post "/forefront/leads/#{widget_pooled.id}/take"

    assert_nil widget_pooled.reload.assigned_to
    assert_equal "You already hold 2 unfinished leads, which is the cap.", flash[:alert]
  end

  test "under the cap a sales person takes as before, and a manager may assign past it" do
    Forefront::Setting.create!(key: "lead_cap", value: "1")
    held_lead("One")
    first = pool_lead("Widget deal", @widget)
    second = pool_lead("Another widget deal", @widget)
    sign_in_as(@rep)
    post "/forefront/leads/#{first.id}/take"
    assert_nil first.reload.assigned_to

    sign_in_as(@manager)
    post "/forefront/leads/#{second.id}/assignments", params: { assignment: { to_user_id: @rep.id } }

    assert_equal @rep, second.reload.assigned_to
  end

  test "the cap is an admin setting, starting at 10" do
    sign_in_as(@admin)
    get "/forefront/settings"
    assert_select "input[name='settings[lead_cap]'][value='10']"

    patch "/forefront/settings", params: { settings: { lead_cap: "5", unassigned_alert_after_hours: "2", stale_after_hours: "24", reveal_action_within_minutes: "60",
                                                       installment_overdue_after_days: "1", default_country_code: "+91" } }

    assert_equal 5, Forefront::Settings.current.lead_cap
  end
end
