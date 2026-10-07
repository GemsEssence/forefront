require "test_helper"

# "How it works": one screen, written for Sales persons, that says how the
# life cycle runs so nobody has to be taught the system by hand.
class Forefront::HelpPageTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "every role finds How it works in the sidebar and it explains the rules in the glossary's words" do
    %w[sales_person manager admin].each do |role|
      sign_in_as(Forefront::Admin.create!(name: "Someone", email: "#{role}-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role))
      get "/forefront/"
      assert_select "aside[data-sidebar] a[href='/forefront/how_it_works']", text: "How it works"
    end

    get "/forefront/how_it_works"

    assert_response :success
    assert_select "h1", text: "How it works"
    %w[pool next\ step deadline Followup Done Private share Receipt Timeline].each do |term|
      assert_match(/#{term}/i, response.body)
    end
    assert_select "section[data-help]", minimum: 6
  end
end
