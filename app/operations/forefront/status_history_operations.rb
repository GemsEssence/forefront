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
        new_status = params[:status]

        # update trackable's status
        if trackable.update(status: new_status)
          trackable.status_histories.create(status_history_params)

          { success: true, trackable: trackable }
        else
          @errors = trackable.errors.full_messages
          { success: false, errors: @errors, trackable: trackable }
        end
      end

      private
      def status_history_params
        params.merge!( changed_by_id: current_admin&.id )
      end
    end
  end
end
