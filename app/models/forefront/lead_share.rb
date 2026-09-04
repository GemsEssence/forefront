module Forefront
  class LeadShare < ApplicationRecord
    belongs_to :lead, class_name: "Forefront::Lead"
    belongs_to :recorded_by, class_name: "Forefront::Admin"
    has_many :lead_share_participants, class_name: "Forefront::LeadShareParticipant", dependent: :destroy, inverse_of: :lead_share

    validate :participants_match_past_assignees_exactly
    validate :percentages_sum_to_100

    private

    def participants_match_past_assignees_exactly
      participant_ids = lead_share_participants.reject(&:marked_for_destruction?).map(&:admin_id).sort
      past_assignee_ids = lead.past_assignees.map(&:id).sort

      return if participant_ids == past_assignee_ids

      errors.add(:base, "must include every sales person the lead was ever assigned to, and no one else")
    end

    def percentages_sum_to_100
      total = lead_share_participants.reject(&:marked_for_destruction?).sum { |p| p.percentage || 0 }

      errors.add(:base, "percentages must add up to 100") unless total == 100
    end
  end
end
