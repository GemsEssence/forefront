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

      # A Lead being won also records what it actually closed for.
      def trackable_attributes
        attributes = { status: params[:status].presence }
        if params[:status] == "won" && trackable.respond_to?(:actual_amount=)
          attributes[:actual_amount] = params[:actual_amount].presence
        end
        attributes
      end
    end
  end
end
