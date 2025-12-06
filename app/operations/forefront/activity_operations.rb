module Forefront
  module ActivityOperations
    class Create
      attr_reader :params, :activity, :errors

      def initialize(params:)
        @params = params
        @errors = []
      end

      def call
        @activity = Activity.new(activity_params)

        if @activity.save
          { success: true, activity: @activity }
        else
          @errors = @activity.errors.full_messages
          { success: false, errors: @errors, activity: @activity }
        end
      end

      private

      def activity_params
        params.permit(:body, :activity_type)
      end
    end
  end
end
