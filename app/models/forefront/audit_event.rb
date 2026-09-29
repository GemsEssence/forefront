module Forefront
  # A permanent record of one thing a Staff member did (see ADR 0006).
  # Written by operations through AuditEvent.record!, never edited.
  class AuditEvent < ApplicationRecord
    belongs_to :actor, class_name: "Forefront::Admin"
    belongs_to :auditable, polymorphic: true, optional: true

    validates :action, presence: true

    scope :recent, -> { order(created_at: :desc, id: :desc) }

    UNAUDITED_ATTRIBUTES = %w[id created_at updated_at].freeze

    # audited_changes defaults to what the operation just saved on the record.
    def self.record!(actor:, action:, auditable:, audited_changes: nil)
      create!(
        actor: actor,
        action: action,
        auditable: auditable,
        auditable_label: label_for(auditable),
        audited_changes: audited_changes || auditable.saved_changes.except(*UNAUDITED_ATTRIBUTES)
      )
    end

    def self.label_for(record)
      record.try(:title) || record.try(:name) || "##{record.id}"
    end

    def readonly?
      persisted?
    end

    def auditable_kind
      auditable_type.to_s.demodulize.underscore.humanize
    end
  end
end
