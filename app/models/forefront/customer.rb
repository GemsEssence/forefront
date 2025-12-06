module Forefront
  class Customer < ApplicationRecord
    has_many :tickets, dependent: :destroy
    has_many :leads, dependent: :destroy

    validates :name, presence: true
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :phone, presence: true

    scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
    scope :by_email, ->(email) { where("email ILIKE ?", "%#{email}%") }
    scope :by_phone, ->(phone) { where("phone ILIKE ?", "%#{phone}%") }
    scope :by_business_name, ->(business_name) { where("business_name ILIKE ?", "%#{business_name}%") }

    def full_name
      business_name.present? ? "#{name} (#{business_name})" : name
    end
  end
end

