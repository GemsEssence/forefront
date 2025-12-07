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

      respond_to do |format|
        if result[:success]
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(assignments_dom_id(@assignable), partial: 'forefront/assignments/history', locals: { assignable: @assignable }),
              turbo_stream.update('flash_messages', partial: 'forefront/assignments/flash', locals: { message: 'Assignee updated.' })
            ]
          end

          format.html { redirect_to @assignable, notice: 'Assignee updated.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(assignments_modal_dom_id(@assignable), partial: 'forefront/assignments/form', locals: { assignable: @assignable, admins: Admin.all.order(:name), errors: result[:errors] }),
              turbo_stream.update('flash_messages', partial: 'forefront/assignments/flash', locals: { message: result[:errors].join(', ') })
            ]
          end

          format.html { redirect_to @assignable, alert: result[:errors].join(', ') }
        end
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

    def assignments_dom_id(assignable)
      "assignments_#{assignable.class.name.demodulize.underscore}_#{assignable.id}"
    end

    def assignments_modal_dom_id(assignable)
      "assignment_modal_#{assignable.class.name.demodulize.underscore}_#{assignable.id}"
    end

    def assignable_params
      params.require(:assignment).permit(:to_user_id, :note)
    end
  end
end
