module Forefront
  # A marketing push run on a Source between two dates (CONTEXT.md). The
  # enquiries it brings in are Tickets credited to it (ADR 0005).
  class Campaign < ApplicationRecord
    belongs_to :source, class_name: "Forefront::Source"
    belongs_to :created_by, class_name: "Forefront::Admin"

    validates :name, :starts_on, :ends_on, presence: true
    validate :ends_after_it_starts
    validate :source_is_active, if: :will_save_change_to_source_id?

    scope :recent, -> { order(starts_on: :desc, id: :desc) }

    private

    def ends_after_it_starts
      errors.add(:ends_on, "can't be before it starts") if starts_on && ends_on && ends_on < starts_on
    end

    def source_is_active
      errors.add(:source, "is no longer in use") if source && !source.active?
    end
  end
end
