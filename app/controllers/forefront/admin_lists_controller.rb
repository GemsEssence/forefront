module Forefront
  # The page for a list Admins maintain (see AdminList). Subclasses name the
  # model and describe the list; the views are shared.
  class AdminListsController < ApplicationController
    before_action :set_record, only: [ :edit, :update, :destroy ]
    before_action :authorize_record, only: [ :edit, :update, :destroy ]

    helper_method :list_model, :list_description

    def index
      authorize list_model
      @records = policy_scope(list_model).ordered
      @record = list_model.new
      render "forefront/admin_lists/index"
    end

    def create
      authorize list_model
      result = AdminListOperations::Create.new(model: list_model, params: record_params, current_admin: current_admin).call

      if result[:success]
        redirect_to url_for(action: :index), notice: "#{list_model.model_name.human} added."
      else
        @records = policy_scope(list_model).ordered
        @record = result[:record]
        flash.now[:alert] = result[:errors].join(", ")
        render "forefront/admin_lists/index", status: :unprocessable_entity
      end
    end

    def edit
      render "forefront/admin_lists/edit"
    end

    def update
      result = AdminListOperations::Update.new(record: @record, params: record_params, current_admin: current_admin).call

      if result[:success]
        redirect_to url_for(action: :index), notice: "#{list_model.model_name.human} updated."
      else
        flash.now[:alert] = result[:errors].join(", ")
        render "forefront/admin_lists/edit", status: :unprocessable_entity
      end
    end

    def destroy
      result = AdminListOperations::Destroy.new(record: @record, current_admin: current_admin).call

      if result[:success]
        redirect_to url_for(action: :index), notice: "#{list_model.model_name.human} deleted.", status: :see_other
      else
        redirect_to url_for(action: :index), alert: result[:errors].join(", "), status: :see_other
      end
    end

    private

    def set_record
      @record = list_model.find(params[:id])
    end

    def authorize_record
      authorize @record
    end

    def record_params
      params.require(list_model.model_name.param_key).permit(:name, :active)
    end
  end
end
