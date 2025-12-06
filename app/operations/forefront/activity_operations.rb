module Forefront
  module ActivityOperations
    class Create
      attr_reader :params, :current_admin, :activity, :errors

      def initialize(params:, actable:, current_admin:)
        @params = params
        @actable = actable
        @current_admin = current_admin
        @errors = []
      end

      def call
        @activity = @actable.activities.build(activity_params)
        @activity.created_by = current_admin

        if @activity.save
          { success: true, activity: @activity }
        else
          @errors = @activity.errors.full_messages
          { success: false, errors: @errors, activity: @activity }
        end
      end

      private

      def activity_params
        params.permit(:activity_type, :body)
      end
    end

    class Update
      attr_reader :activity, :params, :errors

      def initialize(activity:, params:)
        @activity = activity
        @params = params
        @errors = []
      end

      def call
        if @activity.update(activity_params)
          { success: true, activity: @activity }
        else
          @errors = @activity.errors.full_messages
          { success: false, errors: @errors, activity: @activity }
        end
      end

      private

      def activity_params
        params.permit(:activity_type, :body)
      end
    end

    class Destroy
      attr_reader :activity, :errors

      def initialize(activity:)
        @activity = activity
        @errors = []
      end

      def call
        if @activity.destroy
          { success: true }
        else
          @errors = @activity.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end
