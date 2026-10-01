module Forefront
  class CustomersController < ApplicationController
    before_action :set_customer, only: [ :show, :edit, :update, :destroy ]
    before_action :authorize_customer, only: [ :show, :edit, :update, :destroy ]

    def index
      @customers = CustomerServices::Filter.new(
        scope: policy_scope(Customer),
        filters: filter_params
      ).call.page(params[:page])
    end

    def show
    end

    def new
      @customer = Customer.new
      authorize @customer
    end

    def create
      @customer = Customer.new(customer_params)
      authorize @customer

      result = CustomerOperations::Create.new(params: customer_params, current_admin: current_admin).call

      if result[:success]
        redirect_to customer_path(result[:customer]), notice: "Customer was successfully created."
      else
        @customer = result[:customer]
        flash.now[:alert] = result[:errors].join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CustomerOperations::Update.new(
        customer: @customer,
        params: customer_params,
        current_admin: current_admin,
        keep_blank_contact_details: !policy(@customer).see_contact_details?
      ).call

      if result[:success]
        redirect_to customer_path(result[:customer]), notice: "Customer was successfully updated."
      else
        @customer = result[:customer]
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = CustomerOperations::Destroy.new(customer: @customer, current_admin: current_admin).call

      if result[:success]
        redirect_to customers_path, notice: "Customer was successfully deleted."
      else
        redirect_to customers_path, alert: result[:errors].join(", ")
      end
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def authorize_customer
      authorize @customer
    end

    def customer_params
      permitted = %i[name email country_code phone address business_name]
      permitted += %i[external_type external_id] if Forefront.plugin_mode
      params.require(:customer).permit(*permitted)
    end

    def filter_params
      params.permit(:search, :name, :email, :phone, :business_name, :sort_by)
    end
  end
end
