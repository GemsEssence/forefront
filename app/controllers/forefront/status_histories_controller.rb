module Forefront
  class StatusHistoriesController < ApplicationController
    before_action :find_trackable

    def create
      authorize @trackable, :update?
      authorize @trackable, :reopen? if reopening_lead?

      result = Forefront::StatusHistoryOperations::Create.new(
        trackable: @trackable,
        params: status_history_params,
        current_admin: current_admin
      ).call

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

    def reopening_lead?
      @trackable.is_a?(Lead) && (@trackable.won? || @trackable.lost?) &&
        status_history_params[:status].present? && status_history_params[:status] != @trackable.status
    end

    def status_history_params
      params.require(:status_history).permit(:status, :note, :actual_amount, :lost_reason_id)
    end
  end
end
