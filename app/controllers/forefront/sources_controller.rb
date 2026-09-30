module Forefront
  class SourcesController < ApplicationController
    before_action :set_source, only: [ :edit, :update, :destroy ]
    before_action :authorize_source, only: [ :edit, :update, :destroy ]

    def index
      authorize Source
      @sources = policy_scope(Source).ordered
      @source = Source.new
    end

    def create
      authorize Source
      result = SourceOperations::Create.new(params: source_params, current_admin: current_admin).call

      if result[:success]
        redirect_to sources_path, notice: "Source added."
      else
        @sources = policy_scope(Source).ordered
        @source = result[:source]
        flash.now[:alert] = result[:errors].join(", ")
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = SourceOperations::Update.new(source: @source, params: source_params, current_admin: current_admin).call

      if result[:success]
        redirect_to sources_path, notice: "Source updated."
      else
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = SourceOperations::Destroy.new(source: @source, current_admin: current_admin).call

      if result[:success]
        redirect_to sources_path, notice: "Source deleted.", status: :see_other
      else
        redirect_to sources_path, alert: result[:errors].join(", "), status: :see_other
      end
    end

    private

    def set_source
      @source = Source.find(params[:id])
    end

    def authorize_source
      authorize @source
    end

    def source_params
      params.require(:source).permit(:name, :active)
    end
  end
end
