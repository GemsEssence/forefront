require "test_helper"

class Forefront::LeadStageTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "open")
    sign_in_as(@admin)
  end

  def change_stage(stage)
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: stage } }
  end

  test "the change-stage dialog offers the lead stages in order" do
    get "/forefront/leads/#{@lead.id}"

    assert_select "button", text: "Change Stage"
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
    post "/forefront/leads", params: { lead: { title: "Fresh", description: "D", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product.id, status: "negotiation" } }

    assert Forefront::Lead.find_by!(title: "Fresh").open?
  end
end
