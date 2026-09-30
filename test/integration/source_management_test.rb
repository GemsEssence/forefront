require "test_helper"

class Forefront::SourceManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
  end

  test "an admin adds a source and sees it listed" do
    sign_in_as(@admin)
    post "/forefront/sources", params: { source: { name: "Instagram" } }
    assert_redirected_to "/forefront/sources"

    get "/forefront/sources"
    assert_select "tr", text: /Instagram.*Active/m
  end

  test "an admin renames a source" do
    source = Forefront::Source.create!(name: "Linkdin")
    sign_in_as(@admin)

    get "/forefront/sources/#{source.id}/edit"
    assert_response :success
    patch "/forefront/sources/#{source.id}", params: { source: { name: "LinkedIn" } }

    get "/forefront/sources"
    assert_select "tr", text: /LinkedIn/
    assert_select "tr", text: /Linkdin/, count: 0
  end

  test "an admin deactivates a source and can bring it back" do
    source = Forefront::Source.create!(name: "Gitex")
    sign_in_as(@admin)

    patch "/forefront/sources/#{source.id}", params: { source: { active: "0" } }
    get "/forefront/sources"
    assert_select "tr", text: /Gitex.*Inactive/m

    patch "/forefront/sources/#{source.id}", params: { source: { active: "1" } }
    get "/forefront/sources"
    assert_select "tr", text: /Gitex.*Active/m
  end

  test "an admin deletes a source nobody has used" do
    source = Forefront::Source.create!(name: "Typo")
    sign_in_as(@admin)

    delete "/forefront/sources/#{source.id}"

    get "/forefront/sources"
    assert_select "tr", text: /Typo/, count: 0
  end

  test "two sources can't share a name, whatever the case" do
    Forefront::Source.create!(name: "Referral")
    sign_in_as(@admin)

    post "/forefront/sources", params: { source: { name: "referral" } }

    assert_response :unprocessable_entity
    assert_match "Name has already been taken", response.body
  end

  test "adding, renaming and deactivating sources are audited" do
    sign_in_as(@admin)
    post "/forefront/sources", params: { source: { name: "Instagram" } }
    source = Forefront::Source.find_by!(name: "Instagram")
    patch "/forefront/sources/#{source.id}", params: { source: { active: "0" } }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*created.*Source.*Instagram/m
    assert_select "tr", text: /Asha Admin.*updated.*Source.*Instagram.*Active: true → false/m
  end

  test "managers and sales persons can't manage sources" do
    manager = Forefront::Admin.create!(name: "Mona", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    get "/forefront/sources"
    assert_redirected_to "/forefront/"
    assert_no_difference "Forefront::Source.count" do
      post "/forefront/sources", params: { source: { name: "Instagram" } }
    end
  end
end
