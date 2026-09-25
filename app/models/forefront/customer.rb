module Forefront
  class Customer < ApplicationRecord
    has_many :tickets, dependent: :destroy
    has_many :leads, dependent: :destroy
    has_many :subscriptions, class_name: "Forefront::Subscription", dependent: :destroy

    validates :name, presence: true
    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validate :email_or_phone_present
    validates :external_id, uniqueness: { scope: :external_type }, allow_nil: true

    # The form submits "" for an unlinked customer; store that as no link at all,
    # or every unlinked customer after the first fails the uniqueness check above.
    before_validation :normalize_contact_details, :normalize_external_reference

    def self.find_by_external(external_type:, external_id:)
      find_by(external_type: external_type, external_id: external_id)
    end

    scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
    scope :by_email, ->(email) { where("email ILIKE ?", "%#{email}%") }
    scope :by_phone, ->(phone) { where("phone ILIKE ?", "%#{phone}%") }
    scope :by_business_name, ->(business_name) { where("business_name ILIKE ?", "%#{business_name}%") }

    def full_name
      business_name.present? ? "#{name} (#{business_name})" : name
    end

    private

    # Blank strings become nil so several customers without an email don't
    # collide on the unique email index.
    def normalize_contact_details
      self.email = email.to_s.strip.presence
      self.phone = phone.to_s.strip.presence
    end

    def email_or_phone_present
      errors.add(:base, "Provide an email or a phone number") if email.blank? && phone.blank?
    end

    def normalize_external_reference
      self.external_type = external_type.to_s.strip.presence
      self.external_id = external_id.to_s.strip.presence
    end
  end
end
