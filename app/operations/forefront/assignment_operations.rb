module Forefront
  module AssignmentOperations
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
        from_id = assignable.assigned_to_id

        # update assignable's assignee
        if assignable.update(assigned_to_id: to_id)
          assignable.assignments.create(assignment_params)

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

      def assignment_params
        params.merge!( changed_by_id: current_admin&.id )
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
