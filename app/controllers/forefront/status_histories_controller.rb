module Forefront
  class StatusHistoriesController < ApplicationController
    before_action :find_trackable

    def create
      if reopening_lead?
        authorize @trackable, :reopen?
      else
        authorize @trackable, @trackable.is_a?(Lead) ? :move_stage? : :change_status?
      end

      result = if resolving_lead_work?
        authorize @trackable.lead, :move_stage?
        TicketOperations::ResolveLeadWork.new(ticket: @trackable, params: status_history_params, current_admin: current_admin).call
      else
        Forefront::StatusHistoryOperations::Create.new(trackable: @trackable, params: status_history_params, current_admin: current_admin).call
      end

      if result[:success]
        redirect_back fallback_location: @trackable, notice: "Status updated.", status: :see_other
      else
        render_modal_errors helpers.modal_id(:status_history, @trackable),
                            partial: "forefront/status_histories/form",
                            locals: { trackable: @trackable, values: status_history_params },
                            errors: result[:errors], fallback: @trackable
      end
    end

    private

    def find_trackable
      @trackable ||= if params[:ticket_id].present?
        Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        Lead.find(params[:lead_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def resolving_lead_work?
      @trackable.is_a?(Ticket) && @trackable.lead_work? &&
        status_history_params[:status] == "resolved" && status_history_params[:next_step].present?
    end

    def reopening_lead?
      @trackable.is_a?(Lead) && (@trackable.won? || @trackable.lost?) &&
        status_history_params[:status].present? && status_history_params[:status] != @trackable.status
    end

    def status_history_params
      params.require(:status_history).permit(:status, :note, :actual_amount, :lost_reason_id, :ticket_due_at,
                                             :next_step, :next_stage, :followup_on)
    end
  end
end
