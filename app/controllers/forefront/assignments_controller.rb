module Forefront
  class AssignmentsController < ApplicationController
    before_action :find_assignable

    def create
      authorize @assignable, :change_assignee?

      result = Forefront::AssignmentOperations::Create.new(
        assignable: @assignable,
        params: assignable_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_back fallback_location: @assignable, notice: "Assignee updated.", status: :see_other
      else
        redirect_back fallback_location: @assignable, alert: result[:errors].join(", "), status: :see_other
      end
    end

    private

    def find_assignable
      @assignable ||= if params[:ticket_id].present?
        Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        Lead.find(params[:lead_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def assignable_params
      params.require(:assignment).permit(:to_user_id, :note)
    end
  end
end
