require "test_helper"

# Who a Lead's credit may be shared with (CONTEXT.md: Shared Lead): the
# current assignee, plus any Sales person allocated the Product or any
# Manager, whether or not they ever held the Lead. Never an Admin.
class Forefront::LeadSharingRulesTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @colleague = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @outsider = Forefront::Admin.create!(name: "Omar Rep", email: "omar-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = forefront_product(allocated_to: [ @rep, @colleague ])
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "proposal", private: true)
    sign_in_as(@rep)
  end

  def share(percentages)
    post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: percentages } }
  end

  test "the owner shares with a colleague who holds the product but never held the lead, which ends the lead's privacy" do
    get "/forefront/leads/#{@lead.id}"
    assert_select "button", text: "Record Share"
    assert_select "input[name='lead_share[percentages][#{@rep.id}]'][value='100']"
    assert_select "input[name='lead_share[percentages][#{@colleague.id}]']"
    assert_select "input[name='lead_share[percentages][#{@manager.id}]']"
    assert_select "input[name='lead_share[percentages][#{@admin.id}]']", count: 0
    assert_select "input[name='lead_share[percentages][#{@outsider.id}]']", count: 0

    share(@rep.id => "60", @colleague.id => "40", @manager.id => "")

    assert_redirected_to "/forefront/leads/#{@lead.id}"
    assert_equal({ @rep.id => 60, @colleague.id => 40 }, @lead.reload.lead_share.lead_share_participants.to_h { |p| [ p.admin_id, p.percentage.to_i ] })
    assert_not @lead.private?
    sign_in_as(@colleague)
    get "/forefront/leads/#{@lead.id}"
    assert_response :success
  end

  test "a manager can be given a share" do
    share(@rep.id => "70", @manager.id => "30")

    assert_equal 30, @lead.reload.lead_share.lead_share_participants.find_by(admin_id: @manager.id).percentage
  end

  test "the current assignee must be part of the share" do
    share(@colleague.id => "100")

    follow_redirect!
    assert_match "must include the current assignee, Ravi Rep", response.body
    assert_nil @lead.reload.lead_share
  end

  test "an admin, or a sales person without the product, can't be given a share" do
    share(@rep.id => "50", @admin.id => "50")
    follow_redirect!
    assert_match "can only be shared with sales people allocated Widget, and managers", response.body

    share(@rep.id => "50", @outsider.id => "50")
    follow_redirect!
    assert_match "can only be shared with sales people allocated Widget, and managers", response.body
    assert_nil @lead.reload.lead_share
  end
end
