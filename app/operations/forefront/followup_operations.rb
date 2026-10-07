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
        if finishing_without_replacement?
          return { success: false, errors: [ "That would leave #{@followup.followupable.title} without a next step; use Done and say what's next" ], followup: @followup }
        end

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

      # A Lead or Ticket being worked keeps a next step (CONTEXT.md): the
      # only pending Followup can't just be completed or cancelled away.
      def finishing_without_replacement?
        record = @followup.followupable
        return false unless %w[completed cancelled].include?(update_params[:status].to_s) && @followup.pending?
        return false unless record.respond_to?(:other_next_step?) && record.open_for_work?

        !record.other_next_step?(@followup)
      end

      # Called with form params, or with a plain Hash when an Assignment
      # moves the Followups along with the record.
      def update_params
        ActionController::Parameters.new(params.to_h).permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
      end
    end

    # Done (CONTEXT.md: Followup): record the outcome, then what comes next,
    # all of it happening or none of it. The record is never left without a
    # next step.
    class Complete
      NEXTS = %w[followup stage status close].freeze

      attr_reader :followup, :params, :current_admin, :errors

      def initialize(followup:, params:, current_admin:)
        @followup = followup
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def record
        followup.followupable
      end

      def call
        return failure("This followup is already done") unless followup.pending?
        return failure("Outcome can't be blank") if outcome.blank?
        return failure("Say what happens next") unless NEXTS.include?(params[:next].to_s)

        Followup.transaction do
          followup.update!(status: "completed", completed_at: Time.current, outcome: outcome)
          AuditEvent.record!(actor: current_admin, action: "completed_followup", auditable: record,
                             audited_changes: { "followup" => [ nil, "#{followup.followup_type} on #{followup.scheduled_for.strftime("%-d %b %H:%M")}" ],
                                                "outcome" => [ nil, outcome ] })
          take(what_next)
          @errors << "#{record.title} still needs a next step" if errors.empty? && record.reload.open_for_work? && record.needs_next_step?
          raise ActiveRecord::Rollback if errors.any?
        end

        if errors.any?
          followup.reload
          record.reload
          { success: false, errors: errors, followup: followup }
        else
          { success: true, followup: followup }
        end
      end

      private

      def outcome
        params[:outcome].to_s.strip
      end

      def what_next
        case params[:next]
        when "followup"
          Create.new(followupable: record, params: { followup_type: params[:followup_type].presence || "call", scheduled_for: params[:scheduled_for] },
                     current_admin: current_admin).call
        when "stage"
          return { success: false, errors: [ "Only a lead has stages" ] } unless record.is_a?(Lead)

          LeadOperations::StageAction.new(lead: record, params: params, current_admin: current_admin).call
        when "status"
          return { success: false, errors: [ "Only a ticket has a status to change" ] } unless record.is_a?(Ticket)

          StatusHistoryOperations::Create.new(trackable: record, params: { status: params[:status], note: outcome }, current_admin: current_admin).call
        when "close"
          return { success: false, errors: [ "A lead is closed by winning or losing it" ] } unless record.is_a?(Ticket)

          StatusHistoryOperations::Create.new(trackable: record, params: { status: "resolved", note: outcome }, current_admin: current_admin).call
        end
      end

      def take(result)
        @errors += result[:errors] unless result[:success]
      end

      def failure(message)
        @errors = [ message ]
        { success: false, errors: @errors, followup: followup }
      end
    end
  end
end
