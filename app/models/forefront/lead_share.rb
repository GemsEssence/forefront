module Forefront
  class LeadShare < ApplicationRecord
    belongs_to :lead, class_name: "Forefront::Lead"
    belongs_to :recorded_by, class_name: "Forefront::Admin"
    has_many :lead_share_participants, class_name: "Forefront::LeadShareParticipant", dependent: :destroy, inverse_of: :lead_share

    validate :includes_the_current_assignee
    validate :participants_may_hold_the_lead
    validate :percentages_sum_to_100

    private

    def participant_ids
      lead_share_participants.reject(&:marked_for_destruction?).map(&:admin_id)
    end

    # The person holding the Lead is always part of its split.
    def includes_the_current_assignee
      return if lead.assigned_to_id.nil? || participant_ids.include?(lead.assigned_to_id)

      errors.add(:base, "must include the current assignee, #{lead.assigned_to.name}")
    end

    # Anyone who could hold the Lead (CONTEXT.md: Shared Lead), or ever did.
    def participants_may_hold_the_lead
      return if (participant_ids - lead.share_candidates.map(&:id)).empty?

      who = lead.product ? "sales people allocated #{lead.product.name}, and managers" : "managers"
      errors.add(:base, "can only be shared with #{who}")
    end

    def percentages_sum_to_100
      total = lead_share_participants.reject(&:marked_for_destruction?).sum { |p| p.percentage || 0 }

      errors.add(:base, "percentages must add up to 100") unless total == 100
    end
  end
end
