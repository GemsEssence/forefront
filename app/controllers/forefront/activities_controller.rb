module Forefront
  class ActivitiesController < ApplicationController
    def create
      @actable = find_actable
      
      unless can_create_activity?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "activity_form_#{@actable.id}",
              partial: "forefront/activities/form",
              locals: { actable: @actable, error: "You don't have permission to add activities to this #{actable_type}." }
            )
          end
          format.html { redirect_to actable_path, alert: "You don't have permission to add activities to this #{actable_type}." }
        end
        return
      end

      @activity = @actable.activities.build(activity_params)
      @activity.created_by = current_admin

      respond_to do |format|
        if @activity.save
          @activities = @actable.activities.recent
          format.turbo_stream
          format.html { redirect_to actable_path, notice: 'Activity was successfully created.' }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "activity_form_#{@actable.id}",
              partial: "forefront/activities/form",
              locals: { actable: @actable, activity: @activity }
            )
          end
          format.html { redirect_to actable_path, alert: @activity.errors.full_messages.join(', ') }
        end
      end
    end

    private

    def find_actable
      if params[:ticket_id].present?
        Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        Lead.find(params[:lead_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def actable_type
      @actable.class.name.demodulize.downcase
    end

    def actable_path
      if @actable.is_a?(Ticket)
        ticket_path(@actable)
      else
        lead_path(@actable)
      end
    end

    def can_create_activity?
      @actable.created_by_id == current_admin.id || 
      (@actable.respond_to?(:assigned_to_id) && @actable.assigned_to_id == current_admin.id)
    end

    def activity_params
      params.require(:activity).permit(:activity_type, :body)
    end
  end
end

