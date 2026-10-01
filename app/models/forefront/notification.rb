module Forefront
  # An alert telling a Staff member something needs attention (CONTEXT.md).
  class Notification < ApplicationRecord
    KINDS = %w[unassigned still_unassigned stale unanswered_reveal installment_overdue].freeze

    belongs_to :recipient, class_name: "Forefront::Admin"
    belongs_to :subject, polymorphic: true

    validates :kind, inclusion: { in: KINDS }
    validates :message, presence: true

    scope :unread, -> { where(read_at: nil) }
    scope :recent, -> { order(created_at: :desc, id: :desc) }
  end
end
