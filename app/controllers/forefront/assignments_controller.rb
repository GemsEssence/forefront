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
        render_modal_errors helpers.modal_id(:assignment, @assignable),
                            partial: "forefront/assignments/form",
                            locals: { assignable: @assignable, admins: assignee_options, values: assignable_params },
                            errors: result[:errors], fallback: @assignable
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

    # Same choices the Ticket/Lead page offers: Admins never hold work.
    def assignee_options
      Admin.assignable
    end

    def assignable_params
      params.require(:assignment).permit(:to_user_id, :note)
    end
  end
end
