module Forefront
  class EnquiriesController < ApplicationController
    def create
      campaign = Campaign.find(params[:campaign_id])
      authorize campaign, :show?

      result = EnquiryOperations::Record.new(campaign: campaign, params: enquiry_params, current_admin: current_admin).call

      if result[:success]
        redirect_to ticket_path(result[:ticket]), notice: "Enquiry recorded."
      else
        redirect_to campaign_path(campaign), alert: result[:errors].join(", ")
      end
    end

    private

    def enquiry_params
      params.require(:enquiry).permit(:name, :country_code, :phone, :email, :product_id, :note)
    end
  end
end
