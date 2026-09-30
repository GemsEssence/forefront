module Forefront
  module ActivityOperations
    # Activities are audited against the Ticket or Lead they belong to.
    AUDITED_FIELDS = %w[activity_type body].freeze

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
          AuditEvent.record!(actor: current_admin, action: "added_activity", auditable: @actable,
                             audited_changes: AuditEvent.creation_changes(@activity, only: AUDITED_FIELDS))
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
      attr_reader :activity, :params, :current_admin, :errors

      def initialize(activity:, params:, current_admin:)
        @activity = activity
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @activity.update(activity_params)
          if @activity.saved_changes?
            AuditEvent.record!(actor: current_admin, action: "edited_activity", auditable: @activity.actable,
                               audited_changes: @activity.saved_changes.slice(*AUDITED_FIELDS))
          end
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
      attr_reader :activity, :current_admin, :errors

      def initialize(activity:, current_admin:)
        @activity = activity
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @activity.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted_activity", auditable: @activity.actable,
                             audited_changes: @activity.attributes.slice(*AUDITED_FIELDS).transform_values { |value| [ value, nil ] })
          { success: true }
        else
          @errors = @activity.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end
