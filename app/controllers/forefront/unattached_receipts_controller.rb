module Forefront
  # Receipts a Product's application reported that nobody has attached to a
  # Payment yet (CONTEXT.md: Unattached Receipt).
  class UnattachedReceiptsController < ApplicationController
    def index
      @receipts = policy_scope(Receipt).unattached.includes(:product, :customer).order(:received_on, :id)
      @leads = policy_scope(Lead)
    end

    def attach
      receipt = policy_scope(Receipt).unattached.find(params[:id])
      target = ReceiptOperations::Attach.resolve(params[:target])
      authorize target.is_a?(Installment) ? target.payment.lead : target.lead, :attach_receipt? if target

      result = ReceiptOperations::Attach.new(receipt: receipt, target: target, current_admin: current_admin).call
      finish(result, "Receipt attached.")
    end

    def discard
      receipt = policy_scope(Receipt).unattached.find(params[:id])
      authorize receipt, :discard?

      result = ReceiptOperations::Discard.new(receipt: receipt, note: params[:note], current_admin: current_admin).call
      finish(result, "Receipt discarded.")
    end

    private

    def finish(result, notice)
      if result[:success]
        redirect_to unattached_receipts_path, notice: notice, status: :see_other
      else
        redirect_to unattached_receipts_path, alert: result[:errors].join(", "), status: :see_other
      end
    end
  end
end
