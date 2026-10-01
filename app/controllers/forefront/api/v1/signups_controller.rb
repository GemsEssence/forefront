module Forefront
  module Api
    module V1
      # Called by a Product's own application when a customer signs up there,
      # authenticated by that Product's API key, never a Staff session.
      class SignupsController < ActionController::API
        def create
          product = Product.find_by_api_key(bearer_token)
          return render json: { status: "error", errors: [ "Invalid API key" ] }, status: :unauthorized unless product

          result = SignupOperations::Receive.new(product: product, params: signup_params).call

          if result[:success]
            render json: { status: "ok" }, status: result[:status]
          else
            render json: { status: "error", errors: result[:errors] }, status: :unprocessable_entity
          end
        end

        private

        def bearer_token
          request.authorization.to_s[/\ABearer (.+)\z/, 1]
        end

        def signup_params
          params.permit(:name, :country_code, :phone, :email, :external_id)
        end
      end
    end
  end
end
