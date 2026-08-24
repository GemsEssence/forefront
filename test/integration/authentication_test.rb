require "test_helper"

class Forefront::AuthenticationTest < ActionDispatch::IntegrationTest
  test "an admin can sign in and reach the dashboard" do
    email = "alice-#{SecureRandom.hex(4)}@example.com"
    Forefront::Admin.create!(name: "Alice", email: email, password: "password123")

    get "/forefront/admins/sign_in"
    assert_response :success

    post "/forefront/admins/sign_in", params: { admin: { email: email, password: "password123" } }
    assert_redirected_to "/forefront/"
  end

  test "signing in with the wrong password re-renders the sign-in page instead of crashing" do
    email = "alice-#{SecureRandom.hex(4)}@example.com"
    Forefront::Admin.create!(name: "Alice", email: email, password: "password123")

    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: email, password: "wrong-password" } }

    assert_response :success
  end

  test "public sign-up is disabled" do
    get "/forefront/admins/sign_up"
    assert_redirected_to "/forefront/admins/sign_in"

    assert_no_difference "Forefront::Admin.count" do
      post "/forefront/admins", params: { admin: { name: "Eve", email: "eve@example.com", password: "password123" } }
    end
  end

  test "the forgot-password page loads" do
    get "/forefront/admins/password/new"
    assert_response :success
  end
end
