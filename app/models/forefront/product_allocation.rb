module Forefront
  class ProductAllocation < ApplicationRecord
    belongs_to :product, class_name: "Forefront::Product"
    belongs_to :admin, class_name: "Forefront::Admin"

    validates :product_id, uniqueness: { scope: :admin_id, message: "has already been allocated to this admin" }
  end
end
