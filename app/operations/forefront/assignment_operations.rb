module Forefront
  module AssignmentOperations
    # Taking a Ticket or Lead from the Unassigned pool. Taking a Lead stops
    # at the cap (Settings#lead_cap) on unfinished Leads one person may hold;
    # a Manager or Admin assigning past the cap goes through Create as usual.
    class Take
      attr_reader :assignable, :current_admin, :errors

      def initialize(assignable:, current_admin:)
        @assignable = assignable
        @current_admin = current_admin
        @errors = []
      end

      def call
        if assignable.is_a?(Lead)
          held = current_admin.unfinished_leads_count
          if held >= Settings.current.lead_cap
            @errors = [ "You already hold #{held} unfinished #{'lead'.pluralize(held)}, which is the cap." ]
            return { success: false, errors: @errors, assignable: assignable }
          end
        end

        Create.new(assignable: assignable, params: { to_user_id: current_admin.id, from_user_id: nil }, current_admin: current_admin).call
      end
    end

    class Create
      attr_reader :assignable, :params, :current_admin, :errors

      def initialize(assignable:, params:, current_admin:)
        @assignable = assignable
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        to_id = params[:to_user_id]
        from_id = params.key?(:from_user_id) ? params[:from_user_id] : assignable.assigned_to_id

        # update assignable's assignee
        if assignable.update(assigned_to_id: to_id)
          assignable.assignments.create(
            to_user_id: to_id,
            from_user_id: from_id,
            note: params[:note],
            changed_by_id: current_admin&.id
          )

          AuditEvent.record!(actor: current_admin, action: "assigned", auditable: assignable,
                             audited_changes: { "assigned_to" => [ staff_name(from_id), staff_name(to_id) ] })

          # cascade reassign upcoming followups if assignee changed
          if from_id != to_id
            cascade_reassign_followups(from_id, to_id)
          end

          { success: true, assignable: assignable }
        else
          @errors = assignable.errors.full_messages
          { success: false, errors: @errors, assignable: assignable }
        end
      end

      private

      def staff_name(id)
        Admin.find_by(id: id)&.name if id.present?
      end

      def cascade_reassign_followups(from_id, to_id)
        # find upcoming followups assigned to the old assignee
        upcoming_followups = assignable.followups.upcoming.where(assigned_to_id: from_id)
        
        upcoming_followups.each do |followup|
          FollowupOperations::Update.new(
            followup: followup,
            params: { assigned_to_id: to_id },
            current_admin: current_admin
          ).call
        end
      end
    end
  end
end
