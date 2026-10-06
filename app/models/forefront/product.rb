module Forefront
  class Product < ApplicationRecord
    has_many :product_allocations, class_name: "Forefront::ProductAllocation", dependent: :destroy
    has_many :admins, through: :product_allocations
    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error
    has_many :targets, class_name: "Forefront::Target", dependent: :destroy

    validates :name, presence: true
    # Renewal and Reclaim rewards (CONTEXT.md) are a share of the money paid.
    validates :renewal_reward_percentage, :reclaim_reward_percentage,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

    # The key the Product's own application sends to the Signup API.
    def self.find_by_api_key(key)
      find_by(api_key_digest: api_key_digest(key)) if key.present?
    end

    def self.api_key_digest(key)
      OpenSSL::Digest::SHA256.hexdigest(key)
    end

    # Makes a new key, replacing (and so revoking) any earlier one, and
    # returns it. Only its digest is kept, so this is the one chance to see it.
    def generate_api_key!
      key = "ff_#{SecureRandom.base58(40)}"
      update!(api_key_digest: self.class.api_key_digest(key), api_key_last4: key.last(4), api_key_generated_at: Time.current)
      key
    end

    def api_key?
      api_key_digest.present?
    end
  end
end
