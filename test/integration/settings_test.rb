require "test_helper"

class Forefront::SettingsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
  end

  def settings_params(**overrides)
    { unassigned_alert_after_hours: "2", stale_after_hours: "24", reveal_action_within_minutes: "60", installment_overdue_after_days: "1",
      email_unassigned: "1", email_stale: "1", email_unanswered_reveal: "1", email_installment_overdue: "1",
      default_country_code: "+91" }.merge(overrides)
  end

  test "an admin sees the settings, starting from the defaults" do
    sign_in_as(@admin)
    get "/forefront/settings"

    assert_response :success
    assert_select "input[name='settings[unassigned_alert_after_hours]'][value='2']"
    assert_select "input[name='settings[stale_after_hours]'][value='24']"
    assert_select "input[name='settings[reveal_action_within_minutes]'][value='60']"
    assert_select "input[name='settings[installment_overdue_after_days]'][value='1']"
    assert_select "input[type=checkbox][name='settings[email_stale]'][checked]"
    assert_select "input[name='settings[default_country_code]'][value='+91']"
  end

  test "an admin changes the settings and they stick" do
    sign_in_as(@admin)
    patch "/forefront/settings", params: { settings: settings_params(stale_after_hours: "48", email_stale: "0", default_country_code: "+44") }
    assert_redirected_to "/forefront/settings"

    settings = Forefront::Settings.current
    assert_equal 48, settings.stale_after_hours
    assert_equal false, settings.email_stale
    assert_equal "+44", settings.default_country_code
  end

  test "the default country code applies to new customers" do
    sign_in_as(@admin)
    patch "/forefront/settings", params: { settings: settings_params(default_country_code: "+44") }

    get "/forefront/customers/new"
    assert_select "input[name='customer[country_code]'][value='+44']"
    assert_equal "+44", Forefront::Customer.create!(name: "Pat", phone: "7700 900123").country_code
  end

  test "time limits must be whole numbers above zero, and the country code like +91" do
    sign_in_as(@admin)
    patch "/forefront/settings", params: { settings: settings_params(stale_after_hours: "0", default_country_code: "44") }

    assert_response :unprocessable_entity
    assert_match "Stale after hours must be greater than 0", response.body
    assert_match "Default country code must be a + followed by 1 to 4 digits", response.body
    assert_equal 24, Forefront::Settings.current.stale_after_hours
  end

  test "changing settings is audited" do
    sign_in_as(@admin)
    patch "/forefront/settings", params: { settings: settings_params(stale_after_hours: "48") }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*updated settings.*Stale after hours: 24 → 48/m
  end

  test "managers can't change settings" do
    manager = Forefront::Admin.create!(name: "Mona", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    get "/forefront/settings"
    assert_redirected_to "/forefront/"
    patch "/forefront/settings", params: { settings: settings_params(stale_after_hours: "48") }
    assert_equal 24, Forefront::Settings.current.stale_after_hours
  end
end
