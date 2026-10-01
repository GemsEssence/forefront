module Forefront
  module StatusHistoryOperations
    class Create
      # Moving a Lead into one of these stages opens the Ticket for that work.
      STAGE_TICKETS = {
        "demo" => { category: "demo", title: "Schedule demo" },
        "proposal" => { category: "proposal", title: "Send proposal" }
      }.freeze
      DEFAULT_TICKET_DAYS = 2

      attr_reader :trackable, :params, :current_admin, :errors

      def initialize(trackable:, params:, current_admin:)
        @trackable = trackable
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        old_status = trackable.status_before_type_cast

        ActiveRecord::Base.transaction do
          trackable.update!(trackable_attributes)
          trackable.status_histories.create!(
            old_status: old_status,
            new_status: trackable.status_before_type_cast,
            note: params[:note].presence,
            changed_by: current_admin
          )
          AuditEvent.record!(actor: current_admin, action: "changed_status", auditable: trackable)
          open_stage_ticket if trackable.is_a?(Lead) && trackable.saved_change_to_status?
        end

        { success: true, trackable: trackable }
      rescue ActiveRecord::RecordInvalid => e
        @errors = e.record.errors.full_messages
        trackable.restore_attributes
        { success: false, errors: @errors, trackable: trackable }
      rescue ArgumentError
        @errors = [ "Status is not valid" ]
        { success: false, errors: @errors, trackable: trackable }
      end

      private

      # Reuses a still-open Ticket for the same work rather than opening a
      # second; a finished one (a demo already given) means this is new work.
      def open_stage_ticket
        kind = STAGE_TICKETS[trackable.status]
        return if kind.nil? || trackable.tickets.where(category: kind[:category]).where.not(status: %w[resolved closed]).exists?

        result = TicketOperations::Create.new(params: stage_ticket_params(kind), current_admin: current_admin).call
        raise ActiveRecord::RecordInvalid, result[:ticket] unless result[:success]
      end

      def stage_ticket_params(kind)
        ActionController::Parameters.new(
          title: kind[:title],
          description: params[:note].presence || "#{kind[:title]} for #{trackable.title}",
          category: kind[:category],
          priority: "medium",
          status: "open",
          customer_id: trackable.customer_id,
          product_id: trackable.product_id,
          lead_id: trackable.id,
          assigned_to_id: (trackable.assigned_to_id unless trackable.assigned_to&.admin?),
          due_at: params[:ticket_due_at].presence || DEFAULT_TICKET_DAYS.days.from_now.to_date
        )
      end

      # A Lead being won also records what it actually closed for, and one
      # being lost records why, with the change's note as its explanation.
      def trackable_attributes
        attributes = { status: params[:status].presence }
        return attributes unless trackable.is_a?(Lead)

        case params[:status]
        when "won"
          attributes[:actual_amount] = params[:actual_amount].presence
        when "lost"
          attributes[:lost_reason_id] = params[:lost_reason_id].presence
          attributes[:lost_note] = params[:note].presence
        end
        attributes
      end
    end
  end
end
