module Forefront
  module Api
    module V1
      # Called by a Product's own application when a customer signs up there.
      class SignupsController < ProductApiController
        def create
          result = SignupOperations::Receive.new(product: product, params: signup_params).call

          if result[:success]
            render json: { status: "ok" }, status: result[:status]
          else
            render json: { status: "error", errors: result[:errors] }, status: :unprocessable_entity
          end
        end

        private

        def signup_params
          params.permit(:name, :country_code, :phone, :email, :external_id)
        end
      end
    end
  end
end
