module Forefront
  module Api
    module V1
      # Called by a Product's own application when a customer pays in it
      # (CONTEXT.md: Unattached Receipt, ADR 0008).
      class ReceiptsController < ProductApiController
        def create
          result = ReceiptOperations::Receive.new(product: product, params: receipt_params).call

          if result[:success]
            render json: { status: "ok", id: result[:receipt].id }, status: result[:status]
          else
            render json: { status: "error", errors: result[:errors] }, status: :unprocessable_entity
          end
        end

        private

        def receipt_params
          params.permit(:country_code, :phone, :amount, :paid_at, :reference, :method)
        end
      end
    end
  end
end
