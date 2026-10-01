require "test_helper"

class Forefront::CampaignManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @other_rep = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @linkedin = Forefront::Source.create!(name: "LinkedIn")
  end

  def campaign_params(**overrides)
    { name: "LinkedIn September", starts_on: "2026-09-01", ends_on: "2026-09-30", source_id: @linkedin.id }.merge(overrides)
  end

  test "any staff member creates a campaign and everyone sees it listed" do
    sign_in_as(@rep)
    post "/forefront/campaigns", params: { campaign: campaign_params }
    campaign = Forefront::Campaign.find_by!(name: "LinkedIn September")
    assert_redirected_to "/forefront/campaigns/#{campaign.id}"

    sign_in_as(@other_rep)
    get "/forefront/campaigns"
    assert_select "tr", text: /LinkedIn September.*LinkedIn.*1 Sep 2026.*30 Sep 2026/m
  end

  test "a campaign can't end before it starts" do
    sign_in_as(@rep)
    post "/forefront/campaigns", params: { campaign: campaign_params(ends_on: "2026-08-31") }

    assert_response :unprocessable_entity
    assert_match "Ends on can&#39;t be before it starts", response.body
  end

  test "a campaign needs an active source" do
    @linkedin.update!(active: false)
    sign_in_as(@rep)
    post "/forefront/campaigns", params: { campaign: campaign_params }

    assert_response :unprocessable_entity
    assert_match "Source is no longer in use", response.body
  end

  test "whoever created a campaign can edit it; another sales person can't" do
    campaign = Forefront::Campaign.create!(campaign_params(created_by: @rep))

    sign_in_as(@other_rep)
    patch "/forefront/campaigns/#{campaign.id}", params: { campaign: { name: "Hijacked" } }
    assert_equal "LinkedIn September", campaign.reload.name

    sign_in_as(@rep)
    patch "/forefront/campaigns/#{campaign.id}", params: { campaign: { name: "LinkedIn Sept" } }
    assert_equal "LinkedIn Sept", campaign.reload.name
  end

  test "creating a campaign is audited" do
    sign_in_as(@rep)
    post "/forefront/campaigns", params: { campaign: campaign_params }

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*created.*Campaign.*LinkedIn September.*Source: — → LinkedIn/m
  end
end
