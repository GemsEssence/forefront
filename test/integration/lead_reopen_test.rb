require "test_helper"

# A Lost Lead is reopened, never duplicated (CONTEXT.md). Reopening lands on
# Open and the Manager or Admin doing it picks who holds it next, or sends it
# to the pool.
class Forefront::LeadReopenTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @other_rep = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @product = forefront_product(allocated_to: [ @rep, @other_rep ])
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "negotiation")
    @lead.update!(status: "lost", lost_reason: Forefront::LostReason.find_or_create_by!(name: "Price"), lost_note: "Too dear")
  end

  def reopen(assigned_to_id:, note: nil)
    post "/forefront/leads/#{@lead.id}/reopen", params: { reopen: { assigned_to_id: assigned_to_id, note: note } }
  end

  test "a manager reopens a lost lead to Open and hands it to someone, which is recorded" do
    sign_in_as(@manager)

    reopen(assigned_to_id: @other_rep.id, note: "They called back")

    assert_redirected_to "/forefront/leads/#{@lead.id}"
    @lead.reload
    assert @lead.open?
    assert_nil @lead.lost_reason
    assert_nil @lead.lost_note
    assert_equal @other_rep, @lead.assigned_to
    history = @lead.status_histories.order(:created_at).last
    assert_equal [ "Lost", "Open", "They called back", @manager ], [ history.old_status, history.new_status, history.note, history.changed_by ]
    assignment = @lead.assignments.order(:created_at).last
    assert_equal [ @rep, @other_rep, @manager ], [ assignment.from_user, assignment.to_user, assignment.changed_by ]
    assert Forefront::AuditEvent.exists?(actor: @manager, action: "reopened", auditable: @lead)
  end

  test "a manager can send a reopened lead to the pool instead" do
    sign_in_as(@manager)

    reopen(assigned_to_id: "")

    assert @lead.reload.open?
    assert_nil @lead.assigned_to
  end

  test "a sales person can't reopen" do
    sign_in_as(@rep)

    reopen(assigned_to_id: @rep.id)

    assert @lead.reload.lost?
    assert_match "not authorized", flash[:alert]
  end

  test "the lost lead page offers Reopen, not Change Stage, and lists the product's sales people and managers" do
    sign_in_as(@manager)

    get "/forefront/leads/#{@lead.id}"

    assert_select "button", text: "Reopen"
    assert_select "button", text: "Change Stage", count: 0
    assert_select "select[name='reopen[assigned_to_id]'] option", text: "Meera Rep"
    assert_select "select[name='reopen[assigned_to_id]'] option", text: "Mona Manager"
    assert_select "select[name='reopen[assigned_to_id]'] option", text: "Asha Admin", count: 0
    assert_select "select[name='reopen[assigned_to_id]'] option", text: "Unassigned (pool)"
  end

  test "a lost lead can't be moved through the stage dialog any more" do
    sign_in_as(@admin)

    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: "contacted" } }

    assert @lead.reload.lost?
    assert_match "Reopen", flash[:alert]
  end

  test "reopening is refused while the customer has another unfinished lead for the product" do
    Forefront::Lead.create!(title: "Newer", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product, status: "open")
    sign_in_as(@manager)

    reopen(assigned_to_id: @rep.id)

    assert @lead.reload.lost?
    assert_match "already has an unfinished lead", flash[:alert]
  end
end
