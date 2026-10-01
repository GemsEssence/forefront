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
    COUNTRY_CODE_FORMAT = /\A\+\d{1,4}\z/

    validates :email, uniqueness: true, format: { with: EMAIL_FORMAT }, allow_nil: true
    validates :phone, format: { with: PHONE_FORMAT, message: "can only contain digits, spaces, +, -, . and parentheses" }, allow_nil: true
    validates :phone, uniqueness: { scope: :country_code, message: "is already used by another customer" }, allow_nil: true
    validates :country_code, format: { with: COUNTRY_CODE_FORMAT, message: "must be a + followed by 1 to 4 digits" }, if: :phone
    validate :phone_has_plausible_digit_count
    validate :phone_in_its_own_country
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

    def full_phone
      "#{country_code} #{phone}" if phone
    end

    # Contact details as Staff who can't see them are shown them
    # (CONTEXT.md): enough to tell Customers apart, not to call or write.
    def masked_phone
      "#{country_code} #{"•" * (phone.length - 4)}#{phone.last(4)}" if phone
    end

    def masked_email
      return unless email

      local, domain = email.split("@", 2)
      "#{local.first}•••@#{domain}"
    end

    # A number however it's typed ("098765-43210", "+91 98765 43210") as it's
    # stored: digits only, without the country code or a trunk zero.
    def self.national_number(typed, country_code:)
      digits = typed.to_s.delete("^0-9")
      digits = digits.delete_prefix(country_code.to_s.delete("+")) if typed.to_s.strip.start_with?("+")
      digits.sub(/\A0+/, "")
    end

    def full_name
      business_name.present? ? "#{name} (#{business_name})" : name
    end

    private

    # Blank strings become nil so several customers without an email don't
    # collide on the unique email index.
    def normalize_contact_details
      self.email = email.to_s.strip.presence
      typed = phone.to_s.strip.presence
      self.country_code = country_code.to_s.strip.presence || (Forefront.default_country_code if typed)
      @foreign_country_code = false
      return self.phone = typed if typed.nil? || typed !~ PHONE_FORMAT

      @foreign_country_code = typed.start_with?("+") && !typed.delete("^0-9").start_with?(country_code.to_s.delete("+"))
      self.phone = self.class.national_number(typed, country_code: country_code)
    end

    def phone_in_its_own_country
      errors.add(:phone, "starts with a different country code; put it in Country code instead") if @foreign_country_code
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
