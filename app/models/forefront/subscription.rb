module Forefront
  class Subscription < ApplicationRecord
    belongs_to :customer, class_name: "Forefront::Customer"
    belongs_to :product, class_name: "Forefront::Product"
    belongs_to :lead, class_name: "Forefront::Lead"

    validates :expires_at, presence: true

    def expired?
      expires_at.past?
    end
  end
end
