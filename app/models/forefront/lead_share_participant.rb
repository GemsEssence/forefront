module Forefront
  class LeadShareParticipant < ApplicationRecord
    belongs_to :lead_share, class_name: "Forefront::LeadShare", inverse_of: :lead_share_participants
    belongs_to :admin, class_name: "Forefront::Admin"

    validates :percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  end
end
