module Forefront
  # Extending a Lead's or Ticket's Deadline, from the dialog on its page.
  class DeadlinesController < ApplicationController
    def create
      record = params[:ticket_id].present? ? Ticket.find(params[:ticket_id]) : Lead.find(params[:lead_id])
      authorize record, :extend_deadline?

      result = DeadlineOperations::Extend.new(record: record, params: deadline_params, current_admin: current_admin).call

      if result[:success]
        redirect_to record, notice: "Deadline moved to #{record.due_at.strftime("%-d %b %Y")}.", status: :see_other
      else
        render_modal_errors helpers.modal_id(:deadline, record),
                            partial: "forefront/deadlines/form",
                            locals: { record: record, values: deadline_params },
                            errors: result[:errors], fallback: record
      end
    end

    private

    def deadline_params
      params.require(:deadline).permit(:due_at, :note)
    end
  end
end
