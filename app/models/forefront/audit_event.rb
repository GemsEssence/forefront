module Forefront
  # A permanent record of one thing a Staff member did (see ADR 0006).
  # Written by operations through AuditEvent.record!, never edited.
  class AuditEvent < ApplicationRecord
    belongs_to :actor, class_name: "Forefront::Admin"
    belongs_to :auditable, polymorphic: true, optional: true

    validates :action, presence: true

    # The events that count as an Action (CONTEXT.md): creating a Ticket or
    # Lead, an Activity, a Followup, or a stage/status change.
    ACTIONS = %w[
      created added_activity scheduled_followup updated_followup changed_status
      marked_awaiting_customer customer_responded converted
    ].freeze

    scope :recent, -> { order(created_at: :desc, id: :desc) }
    scope :actions, -> { where(action: ACTIONS) }

    UNAUDITED_ATTRIBUTES = %w[id created_at updated_at].freeze

    # audited_changes defaults to what the operation just saved on the record
    # (every attribute it has, for a new one).
    # Foreign keys are stored as the names of the records they point to, so
    # the log still reads "Customer: Acme" after that Customer is renamed or
    # deleted.
    def self.record!(actor:, action:, auditable:, audited_changes: nil)
      changes = audited_changes
      changes ||= auditable.nil? ? {} : default_changes(action, auditable)

      create!(
        actor: actor,
        action: action,
        auditable: auditable,
        auditable_label: label_for(auditable),
        audited_changes: name_foreign_keys(auditable&.class, changes)
      )
    end

    def self.default_changes(action, auditable)
      action == "created" ? creation_changes(auditable) : auditable.saved_changes.except(*UNAUDITED_ATTRIBUTES)
    end

    # saved_changes leaves out attributes that were saved with their column
    # default (a new Lead's "open" status), so a new record lists them all.
    def self.creation_changes(record, only: nil)
      attributes = record.attributes.except(*UNAUDITED_ATTRIBUTES)
      attributes = attributes.slice(*only) if only
      attributes.compact.transform_values { |value| [ nil, value ] }
    end

    def self.label_for(record)
      return if record.nil?

      record.try(:audit_label) || record.try(:title) || record.try(:name) || "##{record.id}"
    end

    def self.name_foreign_keys(model, changes)
      return changes.to_h unless model.respond_to?(:reflect_on_all_associations)

      changes.to_h.each_with_object({}) do |(field, values), named|
        reflection = model.reflect_on_all_associations(:belongs_to).find { |r| !r.polymorphic? && r.foreign_key.to_s == field.to_s }
        if reflection
          named[reflection.name.to_s] = values.map { |id| label_for(reflection.klass.find_by(id: id)) if id.present? }
        else
          named[field.to_s] = values
        end
      end
    end

    def readonly?
      persisted?
    end

    CONTACT_FIELDS = %w[email phone].freeze

    # Only Admins see Customers' contact details, in the log as anywhere else.
    def changes_visible_to(viewer)
      return audited_changes if viewer.admin? || auditable_type != "Forefront::Customer"

      audited_changes.to_h do |field, values|
        CONTACT_FIELDS.include?(field) ? [ field, values.map { |value| "hidden" if value.present? } ] : [ field, values ]
      end
    end

    # "Title: Old → New" lines, as the log page and its CSV show them.
    def change_lines_for(viewer)
      changes_visible_to(viewer).map do |field, (before, after)|
        "#{field.humanize}: #{shown(before)} → #{shown(after)}"
      end
    end

    def auditable_kind
      auditable_type == "Forefront::Admin" ? "Staff" : auditable_type.to_s.demodulize.underscore.humanize
    end

    private

    # false is a real value ("Active: true → false"); only nothing is "—".
    def shown(value)
      value.nil? || value == "" ? "—" : value
    end
  end
end
