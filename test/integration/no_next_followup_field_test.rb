require "test_helper"

# Followup records are the only follow-up (CONTEXT.md: Followup); the old
# free-typed "Next Follow-up" date on Leads and Tickets is gone.
class Forefront::NoNextFollowupFieldTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "the lead and ticket forms don't ask for a next follow-up date" do
    sign_in_as(Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin"))

    get "/forefront/leads/new"
    assert_select "input[name='lead[next_followup_at]']", count: 0
    get "/forefront/tickets/new"
    assert_select "input[name='ticket[next_followup_at]']", count: 0
  end
end
