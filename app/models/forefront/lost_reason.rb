module Forefront
  # Why a Lead was lost (see CONTEXT.md). Always given with a written note.
  class LostReason < ApplicationRecord
    include AdminList

    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error
  end
end
