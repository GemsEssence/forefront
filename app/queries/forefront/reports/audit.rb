module Forefront
  module Reports
    # Sensitive actions in the period: contact reveals, report exports, share
    # changes, settings changes and assignments.
    class Audit < Base
      report key: "audit", title: "Audit report", group: :admin, roles: %w[admin]

      ACTIONS = %w[revealed_contact exported_report recorded_lead_share updated_settings assigned].freeze

      def columns
        [ column(:at, "When", :text), column(:who, "Who", :text), column(:action, "Action", :text),
          column(:record, "Record", :text), column(:changes, "Changes", :text) ]
      end

      def rows
        viewer = context.scope.viewer
        events = AuditEvent.includes(:actor).where(action: ACTIONS, created_at: context.period.times).recent
        events = events.where(actor_id: context.scope.people_ids) if context.scope.people_ids
        events.map do |event|
          [ event.created_at.strftime("%-d %b %Y %H:%M"), event.actor&.name, event.action.humanize,
            event.auditable_label || "—", event.change_lines_for(viewer).join("; ") ]
        end
      end
    end
  end
end
