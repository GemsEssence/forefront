module Forefront
  class LeadSharesController < ApplicationController
    before_action :set_lead
    before_action :authorize_lead

    def new
      @lead_share = @lead.lead_share || @lead.build_lead_share
    end

    def create
      result = LeadShareOperations::Save.new(
        lead: @lead,
        params: lead_share_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to lead_path(@lead), notice: "Lead share recorded."
      else
        redirect_to lead_path(@lead), alert: result[:errors].join(", ")
      end
    end

    private

    def set_lead
      @lead = Lead.find(params[:lead_id])
    end

    def authorize_lead
      authorize @lead, :update?
    end

    def lead_share_params
      params.require(:lead_share).permit(percentages: {})
    end
  end
end
