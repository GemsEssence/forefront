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
          :category, :priority, :status, :due_at, :next_followup_at, :product_id, :renewal_outcome, :lead_id, :campaign_id
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
          :category, :priority, :status, :due_at, :next_followup_at, :product_id, :renewal_outcome, :lead_id
        )
      end
    end

    # Resolving a demo or Proposal Ticket under a Lead, and saying what's next
    # for the Lead: move it to another working stage, wait on the Customer
    # (with a Followup), or nothing yet. All of it happens, or none of it.
    class ResolveLeadWork
      NEXT_STAGES = %w[contacted demo proposal negotiation].freeze

      attr_reader :ticket, :params, :current_admin, :errors

      def initialize(ticket:, params:, current_admin:)
        @ticket = ticket
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        Ticket.transaction do
          resolved = StatusHistoryOperations::Create.new(trackable: ticket, params: params.slice(:status, :note), current_admin: current_admin).call
          @errors = resolved[:errors] unless resolved[:success]
          @errors = next_step_errors if errors.empty?
          raise ActiveRecord::Rollback if errors.any?
        end

        if errors.any?
          ticket.reload
          ticket.lead.reload
          { success: false, errors: errors, trackable: ticket }
        else
          { success: true, trackable: ticket }
        end
      end

      private

      def next_step_errors
        result =
          case params[:next_step]
          when "stage"
            return [ "Pick the stage the lead moves to" ] unless NEXT_STAGES.include?(params[:next_stage])

            StatusHistoryOperations::Create.new(trackable: ticket.lead, params: { status: params[:next_stage] }, current_admin: current_admin).call
          when "awaiting_customer"
            LeadOperations::AwaitCustomer.new(lead: ticket.lead, params: { followup_type: "call", scheduled_for: params[:followup_on] }, current_admin: current_admin).call
          end
        result && !result[:success] ? result[:errors] : []
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

