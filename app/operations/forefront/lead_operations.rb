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
      # first_step: the first Followup (type, time), required when the Lead
      # has an assignee; a Lead for the pool gets one from whoever takes it.
      def initialize(params:, current_admin:, initial_status: "open", first_step: nil)
        @params = params
        @current_admin = current_admin
        @initial_status = initial_status
        @first_step = first_step.presence || {}
        @errors = []
      end

      def call
        @lead = Lead.new(lead_params)
        @lead.status = @initial_status
        @lead.created_by = current_admin
        # A new Lead starts with its creator, unless that's an Admin, who
        # never carries Leads: it goes to the pool instead.
        @lead.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank? && !current_admin.admin?
        # An Admin never creates a Private Lead (CONTEXT.md).
        @lead.private = false if current_admin.admin?

        # A Lead is a journey with exactly one Product (CONTEXT.md). The rule
        # lives here, not on the model, so Leads created before it stay valid.
        # A Lost Lead for the pair is reopened, never duplicated.
        blocking = blocking_lead
        first_step_missing = @lead.assigned_to_id.present? && @first_step[:scheduled_for].blank?
        if blocking.nil? && @lead.product_id.present? && @lead.due_at.present? && !first_step_missing && save_with_first_step
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
          @lead.errors.add(:due_at, :blank) if @lead.due_at.blank?
          @lead.errors.add(:base, "First step can't be blank") if first_step_missing
          @lead.errors.add(:base, @lead.blocking_message_for(blocking)) if blocking && !blocking.active?
          @errors = (@lead.errors.full_messages + @errors).uniq
          { success: false, errors: @errors, lead: @lead, existing_lead: blocking }
        end
      end

      private

      # The Lead and its first Followup land together or not at all.
      def save_with_first_step
        Lead.transaction do
          raise ActiveRecord::Rollback unless @lead.save

          if @first_step[:scheduled_for].present? && @lead.assigned_to_id.present?
            followup = FollowupOperations::Create.new(followupable: @lead, params: @first_step.to_h.merge(assigned_to_id: @lead.assigned_to_id),
                                                      current_admin: current_admin).call
            unless followup[:success]
              @errors = followup[:errors].map { |message| "First step: #{message}" }
              raise ActiveRecord::Rollback
            end
          end
          return true
        end
        false
      end

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
          :source_id, :due_at, :product_id, :expires_at, :estimated_amount, :actual_amount,
          :white_label, :agreement_signed_on, :campaign_id, :private
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
          :source_id, :due_at, :product_id, :expires_at, :estimated_amount, :actual_amount,
          :white_label, :agreement_signed_on, :private
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

