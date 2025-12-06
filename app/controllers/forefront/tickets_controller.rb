module Forefront
  class TicketsController < ApplicationController
    before_action :set_ticket, only: [:show, :edit, :update, :destroy]

    def index
      @tickets = TicketServices::Filter.new(
        scope: Ticket.all,
        filters: filter_params
      ).call
      @customers = Customer.all.order(:name)
      @admins = Admin.all.order(:name)
    end

    def show
      @activities = @ticket.activities.recent
    end

    def new
      @ticket = Ticket.new
      @ticket.customer_id = params[:customer_id] if params[:customer_id].present?
      @customers = Customer.all.order(:name)
      @admins = Admin.all.order(:name)
    end

    def create
      result = TicketOperations::Create.new(
        params: ticket_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to ticket_path(result[:ticket]), notice: 'Ticket was successfully created.'
      else
        @ticket = result[:ticket]
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
      result = TicketOperations::Update.new(
        ticket: @ticket,
        params: ticket_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_to ticket_path(result[:ticket]), notice: 'Ticket was successfully updated.'
      else
        @ticket = result[:ticket]
        @customers = Customer.all.order(:name)
        @admins = Admin.all.order(:name)
        flash.now[:alert] = result[:errors].join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = TicketOperations::Destroy.new(ticket: @ticket).call

      if result[:success]
        redirect_to tickets_path, notice: 'Ticket was successfully deleted.'
      else
        redirect_to tickets_path, alert: result[:errors].join(', ')
      end
    end

    private

    def set_ticket
      @ticket = Ticket.find(params[:id])
    end

    def ticket_params
      params.require(:ticket).permit(
        :title, :description, :customer_id, :assigned_to_id,
        :category, :priority, :status, :due_at, :next_followup_at
      )
    end

    def filter_params
      params.permit(
        :search, :category, :priority, :status, :customer_id,
        :created_by_id, :assigned_to_id, :overdue, :due_soon,
        :needs_followup, :due_from, :due_to, :sort_by
      )
    end
  end
end

