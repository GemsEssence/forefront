module Forefront
  class LeadSharesController < ApplicationController
    before_action :set_lead
    before_action :authorize_lead

    def create
      result = LeadShareOperations::Save.new(
        lead: @lead,
        params: lead_share_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to lead_path(@lead), notice: "Lead share recorded.", status: :see_other
      else
        @lead.reload # drop the rejected, unsaved share so the form shows the saved one
        render_modal_errors helpers.modal_id(:lead_share, @lead),
                            partial: "forefront/lead_shares/form",
                            locals: { lead: @lead, values: lead_share_params[:percentages].to_h },
                            errors: result[:errors], fallback: lead_path(@lead)
      end
    end

    private

    def set_lead
      @lead = Lead.find(params[:lead_id])
    end

    def authorize_lead
      authorize @lead, :share?
    end

    def lead_share_params
      params.require(:lead_share).permit(percentages: {})
    end
  end
end
