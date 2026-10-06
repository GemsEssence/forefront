module Forefront
  module LeadOperations
    # Bringing a Lost Lead back (CONTEXT.md: a Lost Lead is reopened, never
    # duplicated). It lands on Open and the Manager or Admin picks who holds
    # it next, or sends it to the pool.
    class Reopen
      attr_reader :lead, :params, :current_admin, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        return failure("Only a lost lead can be reopened") unless lead.lost?

        Lead.transaction do
          from_id = lead.assigned_to_id
          lead.update!(status: "open", assigned_to_id: params[:assigned_to_id].presence)
          lead.status_histories.create!(old_status: "Lost", new_status: "Open", note: params[:note].presence, changed_by: current_admin)
          AuditEvent.record!(actor: current_admin, action: "reopened", auditable: lead,
                             audited_changes: { "status" => [ "Lost", "Open" ], "assigned_to" => [ Admin.find_by(id: from_id)&.name, lead.assigned_to&.name ] })
          if lead.assigned_to_id.present?
            lead.assignments.create!(to_user_id: lead.assigned_to_id, from_user_id: from_id, changed_by: current_admin, note: params[:note].presence)
          else
            NotificationOperations::AnnounceUnassigned.new(record: lead, created_by: current_admin).call
          end
        end

        { success: true, lead: lead }
      rescue ActiveRecord::RecordInvalid => e
        lead.restore_attributes
        failure(*e.record.errors.full_messages)
      end

      private

      def failure(*messages)
        @errors = messages
        { success: false, errors: @errors, lead: lead }
      end
    end

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

        # A Lead is a journey with exactly one Product (CONTEXT.md). The rule
        # lives here, not on the model, so Leads created before it stay valid.
        # A Lost Lead for the pair is reopened, never duplicated.
        blocking = blocking_lead
        if blocking.nil? && @lead.product_id.present? && @lead.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @lead)
          NotificationOperations::AnnounceUnassigned.new(record: @lead, created_by: current_admin).call

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
          @lead.validate
          @lead.errors.add(:product, :blank) if @lead.product_id.blank?
          @lead.errors.add(:base, @lead.blocking_message_for(blocking)) if blocking && !blocking.active?
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors, lead: @lead, existing_lead: blocking }
        end
      end

      private

      # The unfinished Lead the model refuses to duplicate, or else the Lost
      # one that should be reopened instead. A Won Lead blocks nothing: a
      # lapsed Customer gets a fresh Lead (a Reclaim).
      def blocking_lead
        return if @lead.customer_id.blank? || @lead.product_id.blank?

        siblings = @lead.sibling_leads.to_a
        siblings.find(&:active?) || siblings.find(&:lost?)
      end

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
          @lead.validate
          @lead.errors.add(:product, :blank) if @lead.product_id.blank?
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

