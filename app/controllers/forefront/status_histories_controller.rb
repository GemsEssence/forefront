module Forefront
  class StatusHistoriesController < ApplicationController
    before_action :find_trackable

    def create
      authorize @trackable, :update?

      result = Forefront::StatusHistoryOperations::Create.new(
        trackable: @trackable,
        params: status_history_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_back fallback_location: @trackable, notice: "Status updated.", status: :see_other
      else
        redirect_back fallback_location: @trackable, alert: result[:errors].join(", "), status: :see_other
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

    def status_history_params
      params.require(:status_history).permit(:status, :note, :actual_amount)
    end
  end
end
