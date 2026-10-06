require "test_helper"

class Forefront::LeadShareManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @alice = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @bob = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    sign_in_as(@admin)
    post "/forefront/leads", params: { lead: { title: "L", description: "D", customer_id: @customer.id, assigned_to_id: @alice.id, source_id: forefront_source.id, product_id: forefront_product(allocated_to: [ @alice, @bob ]).id } }
    @lead = Forefront::Lead.order(:created_at).last
  end

  test "recording a share shows the split on the lead page; past assignees are offered an even split" do
    get "/forefront/leads/#{@lead.id}"
    assert_match "Shared Credit", response.body

    patch "/forefront/leads/#{@lead.id}", params: { lead: { assigned_to_id: @bob.id } }

    get "/forefront/leads/#{@lead.id}"
    assert_match "Shared Credit", response.body
    assert_match "Record Share", response.body

    page = Nokogiri::HTML(response.body)
    modal = page.at_css("#lead_share_modal_lead_#{@lead.id}")
    assert modal, "the share form should be a modal on the lead page"
    assert_includes modal["style"].to_s, "display:none"
    assert modal.at_css("input[name='lead_share[percentages][#{@alice.id}]'][value='50.0']")
    assert modal.at_css("input[name='lead_share[percentages][#{@bob.id}]'][value='50.0']")
    assert page.at_css("button[onclick=\"forefrontOpenModal('lead_share_modal_lead_#{@lead.id}')\"]"), "Record Share should open the modal"

    post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @alice.id => "35", @bob.id => "65" } } }
    assert_redirected_to "/forefront/leads/#{@lead.id}"

    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_match "35.0%", response.body
    assert_match "65.0%", response.body
    assert_match "Edit Share", response.body
  end

  test "a mismatched split is rejected with a clear error and nothing saved" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { assigned_to_id: @bob.id } }

    assert_no_difference "Forefront::LeadShare.count" do
      post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @alice.id => "10", @bob.id => "10" } } }
    end
    assert_redirected_to "/forefront/leads/#{@lead.id}"
    follow_redirect!
    assert_match "percentages must add up to 100", response.body
  end

  test "with Turbo, a mismatched split keeps the share modal open with the error and the typed percentages" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { assigned_to_id: @bob.id } }

    post "/forefront/leads/#{@lead.id}/lead_share",
         params: { lead_share: { percentages: { @alice.id => "10", @bob.id => "20" } } }, as: :turbo_stream

    assert_response :unprocessable_entity
    stream = Nokogiri::HTML(response.body).at_css("turbo-stream[action=replace][target=lead_share_modal_lead_#{@lead.id}]")
    assert stream, "expected the share modal to be re-rendered"
    modal = Nokogiri::HTML(stream.at_css("template").inner_html).at_css("#lead_share_modal_lead_#{@lead.id}")
    assert modal["style"].to_s.exclude?("display:none"), "the modal should stay open"
    assert_match "percentages must add up to 100", modal.at_css("[role=alert]").text
    assert modal.at_css("input[name='lead_share[percentages][#{@alice.id}]'][value='10']")
    assert modal.at_css("input[name='lead_share[percentages][#{@bob.id}]'][value='20']")
    assert_nil @lead.reload.lead_share
  end

  test "the old standalone share page is gone" do
    get "/forefront/leads/#{@lead.id}/lead_share/new"
    assert_response :not_found
  end
end
