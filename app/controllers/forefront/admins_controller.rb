module Forefront
  class AdminsController < ApplicationController
    before_action :set_admin, only: [ :edit, :update ]
    before_action :authorize_admin, only: [ :edit, :update ]

    def index
      authorize Admin, :index?
      @admins = policy_scope(Admin).order(:name)
    end

    def new
      @admin = Admin.new(role: "sales_person", manager_id: current_admin.manager? ? current_admin.id : nil)
      authorize @admin
    end

    def create
      @admin = Admin.new(authorization_attributes)
      authorize @admin

      result = AdminOperations::Create.new(params: admin_params, current_admin: current_admin).call

      if result[:success]
        redirect_to admins_path, notice: "Staff member created."
      else
        @admin = result[:admin]
        flash.now[:alert] = result[:errors].join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = AdminOperations::Update.new(admin: @admin, params: admin_params, current_admin: current_admin).call

      if result[:success]
        redirect_to admins_path, notice: "Staff member updated."
      else
        @admin = result[:admin]
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin
      @admin = Admin.find(params[:id])
    end

    def authorize_admin
      authorize @admin
    end

    def admin_params
      params.require(:admin).permit(:name, :email, :password, :password_confirmation, :role, :manager_id)
    end

    def authorization_attributes
      attrs = admin_params.slice(:role, :manager_id)
      attrs[:role] = attrs[:role].presence || "sales_person"
      attrs[:manager_id] = attrs[:manager_id].presence || (current_admin.manager? ? current_admin.id : nil)
      attrs
    end
  end
end
