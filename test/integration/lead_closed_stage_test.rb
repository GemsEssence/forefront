require "test_helper"

class Forefront::LeadClosedStageTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "negotiation")
  end

  def change_stage(stage, **extra)
    post "/forefront/leads/#{@lead.id}/status_histories",
         params: { status_history: { status: stage, **extra } },
         headers: { "HTTP_REFERER" => "http://www.example.com/forefront/leads/#{@lead.id}" }
  end

  def lose_lead
    @lead.update!(status: "lost", lost_reason: Forefront::LostReason.find_or_create_by!(name: "Price"), lost_note: "Too dear")
  end

  def win_lead
    @lead.update!(status: "won", actual_amount: 500, expires_at: 1.year.from_now.to_date)
  end

  test "a sales person can't reopen a lost lead" do
    lose_lead
    sign_in_as(@rep)

    change_stage("contacted")

    assert @lead.reload.lost?
    assert_match "not authorized", flash[:alert]
  end

  test "the sales person's manager can reopen a lost lead, which forgets why it was lost" do
    lose_lead
    sign_in_as(@manager)

    post "/forefront/leads/#{@lead.id}/reopen", params: { reopen: { assigned_to_id: @rep.id, note: "They called back" } }

    assert @lead.reload.open?
    assert_nil @lead.lost_reason
  end

  test "a sales person can't undo a win" do
    win_lead
    sign_in_as(@rep)

    change_stage("negotiation")

    assert @lead.reload.won?
  end

  test "an admin can undo a win that has no payment, and its subscription goes with it" do
    win_lead
    assert @lead.subscription.present?
    sign_in_as(@admin)

    change_stage("negotiation", note: "Marked won by mistake")

    assert @lead.reload.negotiation?
    assert_nil @lead.won_at
    assert_nil @lead.reload.subscription
  end

  test "nobody can undo a win once a payment is recorded" do
    win_lead
    Forefront::Payment.create!(lead: @lead, total_amount: 500)
    sign_in_as(@admin)

    change_stage("negotiation")

    assert @lead.reload.won?
    assert_match "A won lead with a payment recorded can't change stage", flash[:alert]
  end

  test "a sales person still moves their own open lead freely, and can win or lose it" do
    sign_in_as(@rep)

    change_stage("proposal")
    assert @lead.reload.proposal?

    change_stage("won", actual_amount: "500")
    assert @lead.reload.won?
  end
end
