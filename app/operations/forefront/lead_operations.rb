module Forefront
  module LeadOperations
    class Create
      attr_reader :params, :current_admin, :lead, :errors

      # initial_status: a Lead converted from a Ticket starts at Contacted.
      def initialize(params:, current_admin:, initial_status: "open")
        @params = params
        @current_admin = current_admin
        @initial_status = initial_status
        @errors = []
      end

      def call
        @lead = Lead.new(lead_params)
        @lead.status = @initial_status
        @lead.created_by = current_admin
        @lead.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank?

        if @lead.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @lead)

          # Record initial assignment
          if @lead.assigned_to_id.present?
            Forefront::AssignmentOperations::Create.new(
              assignable: @lead,
              params: { to_user_id: @lead.assigned_to_id, from_user_id: nil },
              current_admin: current_admin
            ).call
          end

          { success: true, lead: @lead }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors, lead: @lead }
        end
      end

      private

      def lead_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :source_id, :due_at, :next_followup_at, :product_id, :expires_at, :estimated_amount, :actual_amount,
          :white_label, :agreement_signed_on, :campaign_id
        )
      end
    end

    class Update
      attr_reader :lead, :params, :current_admin, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        previous_assignee = @lead.assigned_to_id

        if @lead.update(lead_params)
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: @lead) if @lead.saved_changes?

          # Record assignment change
          if previous_assignee != @lead.assigned_to_id
            Forefront::AssignmentOperations::Create.new(
              assignable: @lead,
              params: { from_user_id: previous_assignee, to_user_id: @lead.assigned_to_id },
              current_admin: current_admin
            ).call
          end

          { success: true, lead: @lead }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors, lead: @lead }
        end
      end

      private

      def lead_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :source_id, :due_at, :next_followup_at, :product_id, :expires_at, :estimated_amount, :actual_amount,
          :white_label, :agreement_signed_on
        )
      end
    end

    # The Customer has gone quiet: flag the Lead and schedule the Followup that
    # chases them, together or not at all.
    class AwaitCustomer
      attr_reader :lead, :params, :current_admin, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        Lead.transaction do
          unless lead.update(awaiting_customer_since: Time.current)
            @errors = lead.errors.full_messages
            raise ActiveRecord::Rollback
          end

          followup = FollowupOperations::Create.new(followupable: lead, params: params, current_admin: current_admin).call
          unless followup[:success]
            @errors = followup[:errors]
            raise ActiveRecord::Rollback
          end

          AuditEvent.record!(actor: current_admin, action: "marked_awaiting_customer", auditable: lead, audited_changes: {})
        end

        if errors.any?
          lead.reload
          { success: false, errors: errors, lead: lead }
        else
          { success: true, lead: lead }
        end
      end
    end

    class CustomerResponded
      attr_reader :lead, :current_admin, :errors

      def initialize(lead:, current_admin:)
        @lead = lead
        @current_admin = current_admin
        @errors = []
      end

      def call
        if lead.update(awaiting_customer_since: nil)
          AuditEvent.record!(actor: current_admin, action: "customer_responded", auditable: lead, audited_changes: {})
          { success: true, lead: lead }
        else
          @errors = lead.errors.full_messages
          { success: false, errors: errors, lead: lead }
        end
      end
    end

    class Destroy
      attr_reader :lead, :current_admin, :errors

      def initialize(lead:, current_admin:)
        @lead = lead
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @lead.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted", auditable: @lead, audited_changes: {})
          { success: true }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end

