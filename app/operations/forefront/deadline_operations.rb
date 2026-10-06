module Forefront
  module DeadlineOperations
    # A Manager or Admin moving a Lead's or Ticket's Deadline (CONTEXT.md),
    # within the limit again, saying why. Audited, so the Timeline shows it.
    class Extend
      attr_reader :record, :params, :current_admin, :errors

      def initialize(record:, params:, current_admin:)
        @record = record
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        note = params[:note].to_s.strip
        return failure("Say why the deadline is moving") if note.blank?

        was = record.due_at
        if record.update(due_at: params[:due_at].presence)
          AuditEvent.record!(actor: current_admin, action: "extended_deadline", auditable: record,
                             audited_changes: { "due_at" => [ was, record.due_at ], "note" => [ nil, note ] })
          { success: true, record: record }
        else
          messages = record.errors.full_messages
          record.restore_attributes
          failure(*messages)
        end
      end

      private

      def failure(*messages)
        @errors = messages
        { success: false, errors: @errors }
      end
    end
  end
end
