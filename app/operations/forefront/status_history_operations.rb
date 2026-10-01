module Forefront
  module StatusHistoryOperations
    class Create
      attr_reader :trackable, :params, :current_admin, :errors

      def initialize(trackable:, params:, current_admin:)
        @trackable = trackable
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        old_status = trackable.status_before_type_cast

        ActiveRecord::Base.transaction do
          trackable.update!(trackable_attributes)
          trackable.status_histories.create!(
            old_status: old_status,
            new_status: trackable.status_before_type_cast,
            note: params[:note].presence,
            changed_by: current_admin
          )
          AuditEvent.record!(actor: current_admin, action: "changed_status", auditable: trackable)
        end

        { success: true, trackable: trackable }
      rescue ActiveRecord::RecordInvalid => e
        @errors = e.record.errors.full_messages
        trackable.restore_attributes
        { success: false, errors: @errors, trackable: trackable }
      rescue ArgumentError
        @errors = [ "Status is not valid" ]
        { success: false, errors: @errors, trackable: trackable }
      end

      private

      # A Lead being won also records what it actually closed for, and one
      # being lost records why, with the change's note as its explanation.
      def trackable_attributes
        attributes = { status: params[:status].presence }
        return attributes unless trackable.is_a?(Lead)

        case params[:status]
        when "won"
          attributes[:actual_amount] = params[:actual_amount].presence
        when "lost"
          attributes[:lost_reason_id] = params[:lost_reason_id].presence
          attributes[:lost_note] = params[:note].presence
        end
        attributes
      end
    end
  end
end
