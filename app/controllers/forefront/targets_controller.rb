module Forefront
  class TargetsController < ApplicationController
    before_action :set_target, only: [ :edit, :update ]
    before_action :authorize_target, only: [ :edit, :update ]

    def index
      authorize Target, :index?
      @targets = policy_scope(Target).includes(:admin, :product).order(starts_on: :desc)
    end

    def new
      @target = Target.new
      authorize @target
      load_form_collections
    end

    def create
      @target = Target.new(target_params)
      authorize @target

      result = TargetOperations::Create.new(params: target_params).call

      if result[:success]
        redirect_to targets_path, notice: "Target created."
      else
        @target = result[:target]
        load_form_collections
        flash.now[:alert] = result[:errors].join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      result = TargetOperations::Update.new(target: @target, params: target_params).call

      if result[:success]
        redirect_to targets_path, notice: "Target updated."
      else
        @target = result[:target]
        load_form_collections
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_target
      @target = Target.find(params[:id])
    end

    def authorize_target
      authorize @target
    end

    def target_params
      params.require(:target).permit(:admin_id, :product_id, :metric, :goal_value, :period, :starts_on)
    end

    def load_form_collections
      @sales_persons = current_admin.admin? ? Admin.sales_person.order(:name) : current_admin.direct_reports.sales_person.order(:name)
      @products = Product.order(:name)
    end
  end
end
