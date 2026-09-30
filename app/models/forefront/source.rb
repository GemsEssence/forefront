module Forefront
  # Where a Lead came from, or where a Campaign runs (see CONTEXT.md).
  class Source < ApplicationRecord
    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { case_sensitive: false }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name) }

    before_validation { self.name = name.to_s.squish.presence }
  end
end
