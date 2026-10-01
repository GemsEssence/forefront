module Forefront
  # A short list Admins maintain in place of a hard-coded enum (Sources, Lost
  # reasons): unique names, and deactivated entries drop out of pickers while
  # staying on the records that already use them.
  module AdminList
    extend ActiveSupport::Concern

    included do
      validates :name, presence: true, uniqueness: { case_sensitive: false }

      scope :active, -> { where(active: true) }
      scope :ordered, -> { order(:name) }

      before_validation { self.name = name.to_s.squish.presence }
    end
  end
end
