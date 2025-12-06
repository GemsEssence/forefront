module Forefront
  class ActivitiesController < ApplicationController
    before_action :set_activity, only: [:edit, :update, :destroy]
    before_action :find_actable

    def create
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

      result = ActivityOperations::Create.new(
        params: activity_params,
        actable: @actable,
        current_admin: current_admin
      ).call

      respond_to do |format|
        if result[:success]
          @activities = @actable.activities.recent
          format.turbo_stream
          format.html { redirect_to actable_path, notice: 'Activity was successfully created.' }
        else
          @activity = result[:activity]
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "activity_form_#{@actable.id}",
              partial: "forefront/activities/form",
              locals: { actable: @actable, activity: @activity }
            )
          end
          format.html { redirect_to actable_path, alert: result[:errors].join(', ') }
        end
      end
    end

    def edit
      unless can_modify_activity?
        redirect_to actable_path, alert: "You don't have permission to edit this activity."
        return
      end

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def update
      unless can_modify_activity?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "activity_#{@activity.id}",
              partial: "forefront/activities/activity",
              locals: { activity: @activity, index: 0, total: 1 }
            )
          end
          format.html { redirect_to actable_path, alert: "You don't have permission to edit this activity." }
        end
        return
      end

      result = ActivityOperations::Update.new(activity: @activity, params: activity_params).call

      respond_to do |format|
        if result[:success]
          @activities = @actable.activities.recent
          format.turbo_stream
          format.html { redirect_to actable_path, notice: 'Activity was successfully updated.' }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "activity_#{@activity.id}",
              partial: "forefront/activities/activity",
              locals: { activity: @activity, index: 0, total: 1, actable: @actable, editing: true }
            )
          end
          format.html { redirect_to actable_path, alert: result[:errors].join(', ') }
        end
      end
    end

    def destroy
      unless can_modify_activity?
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to actable_path, alert: "You don't have permission to delete this activity." }
        end
        return
      end

      result = ActivityOperations::Destroy.new(activity: @activity).call

      respond_to do |format|
        if result[:success]
          format.turbo_stream
          format.html { redirect_to actable_path, notice: 'Activity was successfully deleted.' }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.append(
              "flash_messages",
              partial: "forefront/shared/flash_message",
              locals: { message: result[:errors].join(', '), type: 'error' }
            )
          end
          format.html { redirect_to actable_path, alert: result[:errors].join(', ') }
        end
      end
    end

    private

    def set_activity
      @activity = Activity.find(params[:id])
      @actable = @activity.actable
    end

    def find_actable
      @actable ||= if params[:ticket_id].present?
        Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        Lead.find(params[:lead_id])
      elsif @activity.present?
        @activity.actable
      else
        raise ActiveRecord::RecordNotFound
      end
    end

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

    def can_modify_activity?
      @activity.created_by_id == current_admin.id
    end

    def activity_params
      params.require(:activity).permit(:activity_type, :body)
    end
  end
end

