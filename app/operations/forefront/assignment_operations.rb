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

        # update assignable's assignee
        if assignable.update(assigned_to_id: to_id)
          assignable.assignments.create(assignment_params)

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
    end
  end
end
