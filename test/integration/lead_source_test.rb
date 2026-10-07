require "test_helper"

class Forefront::LeadSourceTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @linkedin = Forefront::Source.create!(name: "LinkedIn")
    @gitex = Forefront::Source.create!(name: "Gitex", active: false)
    sign_in_as(@admin)
  end

  def create_lead(title, source)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @admin, source: source, status: "open")
  end

  test "the lead form offers only active sources" do
    get "/forefront/leads/new"

    assert_select "select[name='lead[source_id]'] option", text: "LinkedIn"
    assert_select "select[name='lead[source_id]'] option", text: "Gitex", count: 0
  end

  test "a lead is created with a source and shows its name" do
    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: "Big Deal", description: "D", customer_id: @customer.id, source_id: @linkedin.id, product_id: forefront_product.id, status: "open" }, first_step: forefront_first_step }
    lead = Forefront::Lead.find_by!(title: "Big Deal")

    get "/forefront/leads/#{lead.id}"
    assert_match "LinkedIn", response.body
  end

  test "a new lead can't be given an inactive source" do
    post "/forefront/leads", params: { lead: { due_at: (Date.current + 7).iso8601, title: "Big Deal", description: "D", customer_id: @customer.id, source_id: @gitex.id, product_id: forefront_product.id, status: "open" }, first_step: forefront_first_step }

    assert_response :unprocessable_entity
    assert_match "Source is no longer in use", response.body
  end

  test "a lead keeps its source after the source is deactivated, and can still be edited" do
    lead = create_lead("Old Deal", @linkedin)
    @linkedin.update!(active: false)

    get "/forefront/leads/#{lead.id}/edit"
    assert_select "select[name='lead[source_id]'] option[selected]", text: "LinkedIn"

    patch "/forefront/leads/#{lead.id}", params: { lead: { title: "Old Deal renamed", source_id: @linkedin.id } }
    assert_equal "Old Deal renamed", lead.reload.title
  end

  test "renaming a source renames it on every lead" do
    create_lead("Old Deal", @linkedin)
    @linkedin.update!(name: "LinkedIn Ads")

    get "/forefront/leads"
    assert_match "LinkedIn Ads", response.body
  end

  test "leads can be filtered by source" do
    upwork = Forefront::Source.create!(name: "Upwork")
    create_lead("From LinkedIn", @linkedin)
    create_lead("From Upwork", upwork)

    get "/forefront/leads", params: { source_id: upwork.id }

    assert_match "From Upwork", response.body
    assert_no_match "From LinkedIn", response.body
    assert_select "select[name=source_id] option", text: "Gitex"
  end

  test "the CSV export shows the source's name" do
    create_lead("From LinkedIn", @linkedin)

    get "/forefront/leads.csv"

    assert_match "LinkedIn", response.body
  end

  test "a source that leads use can't be deleted" do
    create_lead("From LinkedIn", @linkedin)

    delete "/forefront/sources/#{@linkedin.id}"

    assert Forefront::Source.exists?(@linkedin.id)
    follow_redirect!
    assert_match "Cannot delete record because dependent leads exist", response.body
  end
end
