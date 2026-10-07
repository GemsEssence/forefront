module Forefront
  # Converting a Ticket into a Lead.
  class ConversionsController < ApplicationController
    def create
      ticket = Ticket.find(params[:ticket_id])
      authorize ticket, :convert?

      first_step = params.fetch(:first_step, {}).permit(:followup_type, :scheduled_for)
      result = TicketOperations::ConvertToLead.new(ticket: ticket, params: lead_params, current_admin: current_admin, first_step: first_step).call

      if result[:success]
        redirect_to lead_path(result[:lead]), notice: "Converted to a lead."
      else
        redirect_to ticket_path(ticket), alert: result[:errors].join(", ")
      end
    end

    private

    def lead_params
      params.require(:lead).permit(:title, :estimated_amount, :source_id, :due_at)
    end
  end
end
