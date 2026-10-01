module Forefront
  class ReceiptsController < ApplicationController
    def create
      lead = Lead.find(params[:lead_id])
      authorize lead, :update?
      return redirect_to lead_path(lead), alert: "Record the payment first." unless lead.payment

      result = ReceiptOperations::Create.new(payment: lead.payment, params: receipt_params, current_admin: current_admin).call

      if result[:success]
        redirect_to lead_path(lead), notice: "Receipt recorded."
      else
        redirect_to lead_path(lead), alert: result[:errors].join(", ")
      end
    end

    private

    def receipt_params
      params.require(:receipt).permit(:installment_id, :amount, :received_on, :payment_method, :reference)
    end
  end
end
