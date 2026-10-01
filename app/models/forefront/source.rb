module Forefront
  # Where a Lead came from, or where a Campaign runs (see CONTEXT.md).
  class Source < ApplicationRecord
    include AdminList

    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error
  end
end
