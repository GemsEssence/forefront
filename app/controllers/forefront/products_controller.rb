module Forefront
  class ProductsController < ApplicationController
    before_action :set_product, only: [ :edit, :update ]
    before_action :authorize_product, only: [ :edit, :update ]

    def index
      authorize Product, :index?
      @products = policy_scope(Product).order(:name)
    end

    def new
      @product = Product.new
      authorize @product
      @sales_persons = Admin.sales_person.order(:name)
    end

    def create
      @product = Product.new
      authorize @product

      result = ProductOperations::Create.new(params: product_params, current_admin: current_admin).call

      if result[:success]
        redirect_to products_path, notice: "Product created."
      else
        @product = result[:product]
        @sales_persons = Admin.sales_person.order(:name)
        flash.now[:alert] = result[:errors].join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sales_persons = Admin.sales_person.order(:name)
    end

    def update
      result = ProductOperations::Update.new(product: @product, params: product_params, current_admin: current_admin).call

      if result[:success]
        redirect_to products_path, notice: "Product updated."
      else
        @product = result[:product]
        @sales_persons = Admin.sales_person.order(:name)
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def authorize_product
      authorize @product
    end

    def product_params
      params.require(:product).permit(:name, :description, admin_ids: [])
    end
  end
end
