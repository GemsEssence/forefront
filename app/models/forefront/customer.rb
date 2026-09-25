module Forefront
  class Customer < ApplicationRecord
    has_many :tickets, dependent: :destroy
    has_many :leads, dependent: :destroy
    has_many :subscriptions, class_name: "Forefront::Subscription", dependent: :destroy

    validates :name, presence: true
    # local@domain.tld — URI::MailTo::EMAIL_REGEXP alone accepts "abc@abc".
    EMAIL_FORMAT = /\A[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[a-z]{2,}\z/i
    # Digits with optional leading +, and spaces, dots, dashes or parentheses between.
    PHONE_FORMAT = /\A\+?[\d\s().-]+\z/

    validates :email, uniqueness: true, format: { with: EMAIL_FORMAT }, allow_nil: true
    validates :phone, format: { with: PHONE_FORMAT, message: "can only contain digits, spaces, +, -, . and parentheses" }, allow_nil: true
    validate :phone_has_plausible_digit_count
    validate :email_or_phone_present
    validates :external_id, uniqueness: { scope: :external_type }, allow_nil: true

    # The form submits "" for an unlinked customer; store that as no link at all,
    # or every unlinked customer after the first fails the uniqueness check above.
    before_validation :normalize_contact_details, :normalize_external_reference

    def self.find_by_external(external_type:, external_id:)
      find_by(external_type: external_type, external_id: external_id)
    end

    scope :by_name, ->(name) { where("name #{case_insensitive_like} ?", "%#{name}%") }
    scope :by_email, ->(email) { where("email #{case_insensitive_like} ?", "%#{email}%") }
    scope :by_phone, ->(phone) { where("phone #{case_insensitive_like} ?", "%#{phone}%") }
    scope :by_business_name, ->(business_name) { where("business_name #{case_insensitive_like} ?", "%#{business_name}%") }

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

    def phone_has_plausible_digit_count
      return if phone.nil? || errors[:phone].any?

      digits = phone.count("0-9")
      errors.add(:phone, "must have between 7 and 15 digits") unless digits.between?(7, 15)
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
