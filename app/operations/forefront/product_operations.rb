module Forefront
  module ProductOperations
    class Create
      attr_reader :params, :product, :errors

      def initialize(params:)
        @params = params
        @errors = []
      end

      def call
        @product = Forefront::Product.new(attributes)
        @product.admin_ids = params[:admin_ids] || []

        if @product.save
          { success: true, product: @product }
        else
          @errors = @product.errors.full_messages
          { success: false, product: @product, errors: @errors }
        end
      end

      private

      def attributes
        params.slice(:name, :description, :price)
      end
    end

    class Update
      attr_reader :product, :params, :errors

      def initialize(product:, params:)
        @product = product
        @params = params
        @errors = []
      end

      def call
        product.admin_ids = params[:admin_ids] || []

        if product.update(attributes)
          { success: true, product: product }
        else
          @errors = product.errors.full_messages
          { success: false, product: product, errors: @errors }
        end
      end

      private

      def attributes
        params.slice(:name, :description, :price)
      end
    end
  end
end
