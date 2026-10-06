module Forefront
  # A Sales person or Manager taking a Ticket or Lead from the Unassigned pool.
  class TakesController < ApplicationController
    def create
      assignable = params[:ticket_id] ? Ticket.find(params[:ticket_id]) : Lead.find(params[:lead_id])
      authorize assignable, :take?

      result = AssignmentOperations::Take.new(assignable: assignable, current_admin: current_admin).call

      if result[:success]
        redirect_to assignable, notice: "It's yours.", status: :see_other
      else
        redirect_back fallback_location: unassigned_path, alert: result[:errors].join(", "), status: :see_other
      end
    end
  end
end
