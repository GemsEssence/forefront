module Forefront
  class ProductApiKeysController < ApplicationController
    def create
      @product = Product.find(params[:product_id])
      authorize @product, :generate_api_key?

      @api_key = ProductOperations::GenerateApiKey.new(product: @product, current_admin: current_admin).call[:api_key]
      # Rendered, not redirected: the key mustn't pass through the flash.
      render :show
    end
  end
end
