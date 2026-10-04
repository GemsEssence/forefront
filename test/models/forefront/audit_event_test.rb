require "test_helper"

class Forefront::AuditEventTest < ActiveSupport::TestCase
  test "record! works without an auditable, leaving its label blank" do
    admin = Forefront::Admin.create!(name: "Asha Admin", email: "a-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")

    event = Forefront::AuditEvent.record!(actor: admin, action: "exported_report", auditable: nil, audited_changes: { "report" => [ nil, "lead_stage" ] })

    assert_nil event.auditable_label
    assert_nil event.auditable
    assert_equal({ "report" => [ nil, "lead_stage" ] }, event.reload.audited_changes)
  end
end
