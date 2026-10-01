module Forefront
  # A Sales person taking a Ticket or Lead from the Unassigned pool.
  class TakesController < ApplicationController
    def create
      assignable = params[:ticket_id] ? Ticket.find(params[:ticket_id]) : Lead.find(params[:lead_id])
      authorize assignable, :take?

      result = AssignmentOperations::Create.new(
        assignable: assignable, params: { to_user_id: current_admin.id, from_user_id: nil }, current_admin: current_admin
      ).call

      if result[:success]
        redirect_to assignable, notice: "It's yours.", status: :see_other
      else
        redirect_back fallback_location: unassigned_path, alert: result[:errors].join(", "), status: :see_other
      end
    end
  end
end
