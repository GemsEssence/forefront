module Forefront
  class LeadsController < ApplicationController
    before_action :set_lead, only: [:show, :edit, :update, :destroy]

    def index
      @leads = LeadOperations::Filter.new(
        scope: Lead.all,
        filters: filter_params
      ).call
      @customers = Customer.all.order(:name)
      @admins = Admin.all.order(:name)
    end

    def show
    end

    def new
      @lead = Lead.new
      @lead.customer_id = params[:customer_id] if params[:customer_id].present?
      @customers = Customer.all.order(:name)
      @admins = Admin.all.order(:name)
    end

    def create
      result = LeadOperations::Create.new(
        params: lead_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to lead_path(result[:lead]), notice: 'Lead was successfully created.'
      else
        @lead = result[:lead]
        @customers = Customer.all.order(:name)
        @admins = Admin.all.order(:name)
        flash.now[:alert] = result[:errors].join(', ')
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @customers = Customer.all.order(:name)
      @admins = Admin.all.order(:name)
    end

    def update
      result = LeadOperations::Update.new(
        lead: @lead,
        params: lead_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to lead_path(result[:lead]), notice: 'Lead was successfully updated.'
      else
        @lead = result[:lead]
        @customers = Customer.all.order(:name)
        @admins = Admin.all.order(:name)
        flash.now[:alert] = result[:errors].join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = LeadOperations::Destroy.new(lead: @lead).call

      if result[:success]
        redirect_to leads_path, notice: 'Lead was successfully deleted.'
      else
        redirect_to leads_path, alert: result[:errors].join(', ')
      end
    end

    private

    def set_lead
      @lead = Lead.find(params[:id])
    end

    def lead_params
      params.require(:lead).permit(
        :title, :description, :customer_id, :assigned_to_id,
        :source, :status, :due_at, :next_followup_at
      )
    end

    def filter_params
      params.permit(
        :search, :source, :status, :customer_id,
        :created_by_id, :assigned_to_id, :overdue, :due_soon,
        :needs_followup, :active, :won, :lost, :due_from, :due_to, :sort_by
      )
    end
  end
end

