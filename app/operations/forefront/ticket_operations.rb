module Forefront
  module TicketOperations
    class Create
      attr_reader :params, :current_admin, :ticket, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @ticket = Ticket.new(ticket_params)
        @ticket.created_by = current_admin
        @ticket.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank? && !current_admin.admin?

        if @ticket.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @ticket)

          # Record initial assignment (from system / nil to assigned admin)
          if @ticket.assigned_to_id.present?
            Forefront::AssignmentOperations::Create.new(
              assignable: @ticket,
              params: { to_user_id: @ticket.assigned_to_id, from_user_id: nil },
              current_admin: current_admin
            ).call
          end
          { success: true, ticket: @ticket }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors, ticket: @ticket }
        end
      end

      private

      def ticket_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :category, :priority, :status, :due_at, :next_followup_at, :product_id, :renewal_outcome
        )
      end
    end

    class Update
      attr_reader :ticket, :params, :current_admin, :errors

      def initialize(ticket:, params:, current_admin:)
        @ticket = ticket
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        previous_assignee = @ticket.assigned_to_id

        if @ticket.update(ticket_params)
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: @ticket) if @ticket.saved_changes?

          # If assignee changed, record assignment
          if previous_assignee != @ticket.assigned_to_id
            Forefront::AssignmentOperations::Create.new(
              assignable: @ticket,
              params: { from_user_id: previous_assignee, to_user_id: @ticket.assigned_to_id },
              current_admin: current_admin
            ).call
          end

          { success: true, ticket: @ticket }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors, ticket: @ticket }
        end
      end

      private

      def ticket_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :category, :priority, :status, :due_at, :next_followup_at, :product_id, :renewal_outcome
        )
      end
    end

    class Destroy
      attr_reader :ticket, :current_admin, :errors

      def initialize(ticket:, current_admin:)
        @ticket = ticket
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @ticket.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted", auditable: @ticket, audited_changes: {})
          { success: true }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end

