module Forefront
  # Where a Ticket or Lead came from, or where a Campaign runs (see CONTEXT.md).
  class Source < ApplicationRecord
    include AdminList

    has_many :leads, class_name: "Forefront::Lead", dependent: :restrict_with_error
    has_many :tickets, class_name: "Forefront::Ticket", dependent: :restrict_with_error
    has_many :campaigns, class_name: "Forefront::Campaign", dependent: :restrict_with_error

    # Where a Lead converted from a Signup Ticket came from.
    def self.signup
      find_or_create_by!(name: "Signup")
    end
  end
end
