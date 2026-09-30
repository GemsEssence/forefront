module Forefront
  module FollowupOperations
    # Followups are audited against the record they're scheduled on.
    UNAUDITED_FIELDS = (AuditEvent::UNAUDITED_ATTRIBUTES + %w[followupable_type followupable_id created_by_id]).freeze

    class Create
      attr_reader :followupable, :params, :current_admin, :errors

      def initialize(followupable:, params:, current_admin:)
        @followupable = followupable
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        # default assignee to the parent assignable's assigned_to if not provided
        assigned_id = params[:assigned_to_id].presence || followupable.assigned_to_id

        followup = followupable.followups.new(
          assigned_to_id: assigned_id,
          followup_type: params[:followup_type] || 'call',
          scheduled_for: params[:scheduled_for],
          status: params[:status] || 'pending',
          outcome: params[:outcome],
          created_by_id: current_admin&.id
        )

        if followup.save
          AuditEvent.record!(actor: current_admin, action: "scheduled_followup", auditable: followupable,
                             audited_changes: AuditEvent.creation_changes(followup).except(*UNAUDITED_FIELDS))
          { success: true, followup: followup }
        else
          { success: false, errors: followup.errors.full_messages, followup: followup }
        end
      end
    end

    class Update
      attr_reader :followup, :params, :current_admin, :errors

      def initialize(followup:, params:, current_admin:)
        @followup = followup
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @followup.update(update_params)
          if @followup.saved_changes?
            AuditEvent.record!(actor: current_admin, action: "updated_followup", auditable: @followup.followupable,
                               audited_changes: @followup.saved_changes.except(*UNAUDITED_FIELDS))
          end

          # set completed_at when status becomes completed
          if @followup.status == 'completed' && @followup.completed_at.nil?
            @followup.update_column(:completed_at, Time.current)
          end
          # clear completed_at if status changed away from completed
          if @followup.status != 'completed' && @followup.completed_at.present?
            @followup.update_column(:completed_at, nil)
          end

          { success: true, followup: @followup }
        else
          { success: false, errors: @followup.errors.full_messages, followup: @followup }
        end
      end

      private

      def update_params
        params.permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
      end
    end
  end
end
