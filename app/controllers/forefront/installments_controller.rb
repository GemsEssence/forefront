module Forefront
  class InstallmentsController < ApplicationController
    before_action :set_lead
    before_action :authorize_lead

    def create
      result = InstallmentOperations::Create.new(payment: @lead.payment, params: installment_params, current_admin: current_admin).call

      if result[:success]
        redirect_to lead_path(@lead), notice: "Installment added."
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

    def installment_params
      params.require(:installment).permit(:amount, :due_on)
    end
  end
end
