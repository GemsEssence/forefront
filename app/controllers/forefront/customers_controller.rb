module Forefront
  class CustomersController < ApplicationController
    before_action :set_customer, only: [:show, :edit, :update, :destroy]

    def index
      @customers = CustomerOperations::Filter.new(
        scope: Customer.all,
        filters: filter_params
      ).call
    end

    def show
    end

    def new
      @customer = Customer.new
    end

    def create
      result = CustomerOperations::Create.new(params: customer_params).call

      if result[:success]
        redirect_to customer_path(result[:customer]), notice: 'Customer was successfully created.'
      else
        @customer = result[:customer]
        flash.now[:alert] = result[:errors].join(', ')
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CustomerOperations::Update.new(
        customer: @customer,
        params: customer_params
      ).call

      if result[:success]
        redirect_to customer_path(result[:customer]), notice: 'Customer was successfully updated.'
      else
        @customer = result[:customer]
        flash.now[:alert] = result[:errors].join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = CustomerOperations::Destroy.new(customer: @customer).call

      if result[:success]
        redirect_to customers_path, notice: 'Customer was successfully deleted.'
      else
        redirect_to customers_path, alert: result[:errors].join(', ')
      end
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(:name, :email, :phone, :address, :business_name)
    end

    def filter_params
      params.permit(:search, :name, :email, :phone, :business_name, :sort_by)
    end
  end
end

