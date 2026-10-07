module Forefront
  module TicketOperations
    class Create
      attr_reader :params, :current_admin, :ticket, :errors

      # first_step: an optional first Followup (type, time) for the assignee.
      def initialize(params:, current_admin:, first_step: nil)
        @params = params
        @current_admin = current_admin
        @first_step = first_step.presence || {}
        @errors = []
      end

      def call
        @ticket = Ticket.new(ticket_params)
        @ticket.created_by = current_admin
        # A Ticket always has a Deadline (CONTEXT.md); left blank, it gets the limit.
        @ticket.due_at ||= Ticket.latest_deadline
        @ticket.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank? && !current_admin.admin?

        if @ticket.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @ticket)
          NotificationOperations::AnnounceUnassigned.new(record: @ticket, created_by: current_admin).call

          # Record initial assignment (from system / nil to assigned admin)
          if @ticket.assigned_to_id.present?
            Forefront::AssignmentOperations::Create.new(
              assignable: @ticket,
              params: { to_user_id: @ticket.assigned_to_id, from_user_id: nil },
              current_admin: current_admin
            ).call
          end
          if @first_step[:scheduled_for].present? && @ticket.assigned_to_id.present?
            FollowupOperations::Create.new(followupable: @ticket, params: @first_step.to_h.merge(assigned_to_id: @ticket.assigned_to_id),
                                           current_admin: current_admin).call
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
          :category, :priority, :status, :due_at, :product_id, :renewal_outcome, :lead_id, :campaign_id
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
          :category, :priority, :status, :due_at, :product_id, :renewal_outcome, :lead_id
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
        return [ "Say what's next for the lead" ] unless %w[stage awaiting_customer].include?(params[:next_step])

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

    # Converting a Ticket into a Lead once the Customer is ready to be asked to
    # buy (CONTEXT.md): the Lead takes the Ticket's Customer, Product,
    # assignee and Campaign and starts at Contacted; the Ticket becomes its
    # first Ticket and is resolved.
    class ConvertToLead
      attr_reader :ticket, :params, :current_admin, :errors, :lead

      def initialize(ticket:, params:, current_admin:, first_step: nil)
        @ticket = ticket
        @params = params
        @current_admin = current_admin
        @first_step = first_step
        @errors = []
      end

      def call
        Ticket.transaction do
          created = LeadOperations::Create.new(params: ActionController::Parameters.new(lead_attributes), current_admin: current_admin,
                                               initial_status: "contacted", first_step: @first_step).call
          @lead = created[:lead]
          @errors = created[:errors] unless created[:success]
          resolve_ticket if errors.empty?
          raise ActiveRecord::Rollback if errors.any?
        end

        errors.any? ? { success: false, errors: errors } : { success: true, lead: lead }
      end

      private

      def lead_attributes
        {
          title: params[:title], description: ticket.description, estimated_amount: params[:estimated_amount],
          source_id: params[:source_id], customer_id: ticket.customer_id, product_id: ticket.product_id,
          assigned_to_id: ticket.assigned_to_id || (current_admin.id unless current_admin.admin?), campaign_id: ticket.campaign_id,
          due_at: params[:due_at].presence || Lead.latest_deadline
        }
      end

      def resolve_ticket
        ticket.update!(lead: lead)
        resolved = StatusHistoryOperations::Create.new(trackable: ticket, params: { status: "resolved", note: "Converted to lead #{lead.title}" },
                                                      current_admin: current_admin).call
        return @errors = resolved[:errors] unless resolved[:success]

        AuditEvent.record!(actor: current_admin, action: "converted", auditable: ticket, audited_changes: { "lead" => [ nil, lead.title ] })
      rescue ActiveRecord::RecordInvalid => e
        @errors = e.record.errors.full_messages
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

