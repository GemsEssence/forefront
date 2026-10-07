require "test_helper"

class Forefront::LeadStageTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @admin, assigned_to: @admin, source: forefront_source, status: "open")
    sign_in_as(@admin)
  end

  def change_stage(stage)
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: stage } }
  end

  test "a manager's Move stage dialog offers the lead stages in order; the sales person gets actions instead" do
    get "/forefront/leads/#{@lead.id}"
    assert_select "[data-stage-actions] button", text: "Customer reached"
    assert_select "button", text: "Move stage", count: 0

    manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @admin.update!(manager: manager)
    delete "/forefront/admins/sign_out"
    sign_in_as(manager)
    get "/forefront/leads/#{@lead.id}"

    assert_select "button", text: "Move stage"
    options = css_select("#status_history_modal_lead_#{@lead.id} select#status_history_status option").map(&:text).reject(&:blank?)
    assert_equal [ "Open", "Contacted", "Demo", "Proposal", "Negotiation", "Won", "Lost" ], options
  end

  test "a lead moves forward and back between the working stages, and each move is recorded" do
    change_stage("contacted")
    change_stage("proposal")
    change_stage("demo")

    assert @lead.reload.demo?
    assert_equal [ %w[Open Contacted], %w[Contacted Proposal], %w[Proposal Demo] ],
                 @lead.status_histories.order(:created_at).pluck(:old_status, :new_status)
  end

  test "editing a lead doesn't change its stage; only the dialog does" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { title: "Bigger Deal", status: "negotiation" } }

    assert_equal "Bigger Deal", @lead.reload.title
    assert @lead.open?
  end

  test "a new lead starts at Open" do
    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: "Fresh", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product(allocated_to: @admin).id, status: "negotiation" }, first_step: forefront_first_step }

    assert Forefront::Lead.find_by!(title: "Fresh").open?
  end
end
