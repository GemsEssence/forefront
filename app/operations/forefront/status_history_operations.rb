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
          trackable.update!(status: params[:status].presence)
          trackable.status_histories.create!(
            old_status: old_status,
            new_status: trackable.status_before_type_cast,
            note: params[:note].presence,
            changed_by: current_admin
          )
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
    end
  end
end
