module Forefront
  class AwaitingCustomersController < ApplicationController
    before_action :set_lead

    def create
      authorize @lead, :work?
      result = LeadOperations::AwaitCustomer.new(lead: @lead, params: followup_params, current_admin: current_admin).call

      if result[:success]
        redirect_back fallback_location: lead_path(@lead), notice: "Waiting on the customer; followup scheduled.", status: :see_other
      else
        redirect_back fallback_location: lead_path(@lead), alert: result[:errors].join(", "), status: :see_other
      end
    end

    def destroy
      authorize @lead, :work?
      result = LeadOperations::CustomerResponded.new(lead: @lead, current_admin: current_admin).call

      if result[:success]
        redirect_back fallback_location: lead_path(@lead), notice: "Marked as responded.", status: :see_other
      else
        redirect_back fallback_location: lead_path(@lead), alert: result[:errors].join(", "), status: :see_other
      end
    end

    private

    def set_lead
      @lead = Lead.find(params[:lead_id])
    end

    def followup_params
      params.require(:followup).permit(:followup_type, :scheduled_for, :outcome)
    end
  end
end
