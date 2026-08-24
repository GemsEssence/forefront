module Forefront
  class Product < ApplicationRecord
    has_many :product_allocations, class_name: "Forefront::ProductAllocation", dependent: :destroy
    has_many :admins, through: :product_allocations
    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error
    has_many :targets, class_name: "Forefront::Target", dependent: :destroy

    validates :name, presence: true
    validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  end
end
