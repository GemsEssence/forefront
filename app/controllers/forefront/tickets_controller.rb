module Forefront
  class TicketsController < ApplicationController
    before_action :set_ticket, only: [:show, :edit, :update, :destroy]
    before_action :authorize_ticket, only: [:show, :edit, :update, :destroy]

    def index
      @tickets = TicketServices::Filter.new(
        scope: policy_scope(Ticket),
        filters: filter_params
      ).call.page(params[:page])
      @customers = Customer.all.order(:name)
      @admins = Admin.assignable
    end

    def show
      @activities = @ticket.activities.recent
      @assignments = @ticket.assignments.order(created_at: :desc)
      @admins = Admin.assignable
    end

    def new
      @ticket = Ticket.new
      @ticket.customer_id = params[:customer_id] if params[:customer_id].present?
      prefill_from_lead
      authorize @ticket
      @customers = Customer.all.order(:name)
      @admins = Admin.assignable
      @products = Product.all.order(:name)
    end

    def create
      @ticket = Ticket.new(ticket_params)
      @ticket.created_by = current_admin
      authorize @ticket

      @first_step = params.fetch(:first_step, {}).permit(:followup_type, :scheduled_for)
      result = if lead_visible?
        TicketOperations::Create.new(params: ticket_params, current_admin: current_admin, first_step: @first_step).call
      else
        { success: false, ticket: @ticket, errors: [ "Lead not found" ] }
      end

      if result[:success]
        redirect_to ticket_path(result[:ticket]), notice: 'Ticket was successfully created.'
      else
        @ticket = result[:ticket]
        @customers = Customer.all.order(:name)
        @admins = Admin.assignable
        @products = Product.all.order(:name)
        flash.now[:alert] = result[:errors].join(', ')
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @customers = Customer.all.order(:name)
      @admins = Admin.assignable
      @products = Product.all.order(:name)
    end

    def update
      result = if lead_visible?
        TicketOperations::Update.new(ticket: @ticket, params: ticket_params, current_admin: current_admin).call
      else
        { success: false, ticket: @ticket, errors: [ "Lead not found" ] }
      end

      if result[:success]
        redirect_to ticket_path(result[:ticket]), notice: 'Ticket was successfully updated.'
      else
        @ticket = result[:ticket]
        @customers = Customer.all.order(:name)
        @admins = Admin.assignable
        @products = Product.all.order(:name)
        flash.now[:alert] = result[:errors].join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = TicketOperations::Destroy.new(ticket: @ticket, current_admin: current_admin).call

      if result[:success]
        redirect_to tickets_path, notice: 'Ticket was successfully deleted.'
      else
        redirect_to tickets_path, alert: result[:errors].join(', ')
      end
    end

    private

    # A Ticket can only be put under a Lead the Staff member can see.
    def lead_visible?
      ticket_params[:lead_id].blank? || policy_scope(Lead).exists?(id: ticket_params[:lead_id])
    end

    # "New Ticket for this Lead" starts from the Lead's Customer, Product and
    # assignee.
    def prefill_from_lead
      lead = policy_scope(Lead).find_by(id: params[:lead_id]) if params[:lead_id].present?
      return unless lead

      @ticket.assign_attributes(lead: lead, customer: lead.customer, product: lead.product, assigned_to: lead.assigned_to)
    end

    def set_ticket
      @ticket = Ticket.find(params[:id])
    end

    def authorize_ticket
      authorize @ticket
    end

    def ticket_params
      params.require(:ticket).permit(
        :title, :description, :customer_id, :assigned_to_id,
        :category, :priority, :status, :due_at, :product_id, :renewal_outcome, :lead_id
      )
    end

    def filter_params
      params.permit(
        :search, :category, :priority, :status, :customer_id,
        :created_by_id, :assigned_to_id, :sort_by
      )
    end
  end
end


