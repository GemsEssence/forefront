module Forefront
  # The settings Admins change on the Settings page, typed and with their
  # defaults. Settings.current reads what's been saved over the defaults.
  class Settings
    include ActiveModel::Model
    include ActiveModel::Attributes

    # When each kind of Notification fires (CONTEXT.md: Notification).
    attribute :unassigned_alert_after_hours, :integer, default: 2
    attribute :stale_after_hours, :integer, default: 24
    attribute :reveal_action_within_minutes, :integer, default: 60
    attribute :installment_overdue_after_days, :integer, default: 1
    # Whether each kind is also emailed.
    attribute :email_unassigned, :boolean, default: true
    attribute :email_stale, :boolean, default: true
    attribute :email_unanswered_reveal, :boolean, default: true
    attribute :email_installment_overdue, :boolean, default: true
    # How many unfinished Leads one person may hold before they can't take
    # more from the pool (CONTEXT.md: Unassigned pool).
    attribute :lead_cap, :integer, default: 10
    # How far ahead of a Subscription's expiry the Expiry pull opens a
    # Renewal Ticket (CONTEXT.md: Renewal).
    attribute :renewal_window_days, :integer, default: 30
    # Starts as the host's initializer value (Forefront.default_country_code).
    attribute :default_country_code, :string, default: -> { Forefront.default_country_code }

    validates :unassigned_alert_after_hours, :stale_after_hours, :reveal_action_within_minutes, :installment_overdue_after_days, :lead_cap, :renewal_window_days,
              numericality: { only_integer: true, greater_than: 0 }
    validates :default_country_code, format: { with: Customer::COUNTRY_CODE_FORMAT, message: "must be a + followed by 1 to 4 digits" }

    def self.current
      new(Setting.where(key: attribute_names).pluck(:key, :value).to_h)
    end

    # Form params arrive as settings[...]; Pundit then needs telling where
    # the policy is.
    def self.model_name
      ActiveModel::Name.new(self, nil, "Settings")
    end

    def self.policy_class
      SettingsPolicy
    end

    # Saves every setting; returns the changes as audit-log pairs.
    def save
      return false unless valid?

      before = self.class.current
      changes = attribute_names.each_with_object({}) do |name, changed|
        changed[name] = [ before.public_send(name), public_send(name) ] if before.public_send(name) != public_send(name)
      end

      Setting.transaction do
        attribute_names.each { |name| Setting.find_or_initialize_by(key: name).update!(value: public_send(name).to_s) }
      end
      changes
    end

    def persisted?
      true
    end
  end
end
