module Forefront
  module Api
    module V1
      # Endpoints a Product's own application calls, authenticated by that
      # Product's API key (a Bearer token), never a Staff session.
      class ProductApiController < ActionController::API
        before_action :authenticate_product!

        private

        attr_reader :product

        def authenticate_product!
          @product = Product.find_by_api_key(bearer_token)
          render json: { status: "error", errors: [ "Invalid API key" ] }, status: :unauthorized unless @product
        end

        def bearer_token
          request.authorization.to_s[/\ABearer (.+)\z/, 1]
        end
      end
    end
  end
end
