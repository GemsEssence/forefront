module Forefront
  class PaymentsController < ApplicationController
    before_action :set_lead
    before_action :authorize_lead

    def new
      redirect_to lead_path(@lead), alert: "Lead must be won before recording a payment." and return unless @lead.won?
      redirect_to lead_path(@lead), notice: "Payment already recorded." and return if @lead.payment.present?

      @payment = @lead.build_payment
    end

    def create
      result = PaymentOperations::Create.new(lead: @lead, params: payment_params).call

      if result[:success]
        redirect_to lead_path(@lead), notice: "Payment recorded."
      else
        redirect_to lead_path(@lead), alert: result[:errors].join(", ")
      end
    end

    def update
      result = PaymentOperations::MarkPaid.new(payment: @lead.payment).call

      if result[:success]
        redirect_to lead_path(@lead), notice: "Payment marked as paid."
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

    def payment_params
      params.require(:payment).permit(:total_amount)
    end
  end
end
