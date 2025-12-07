module Forefront
  class ActivitiesController < ApplicationController
    before_action :set_activity, only: [:edit, :update, :destroy]
    before_action :find_actable

    def create
      @activity = @actable.activities.build(activity_params)
      @activity.created_by = current_admin
      authorize @activity

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
      authorize @activity

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def update
      authorize @activity

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
      authorize @activity

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

    def activity_params
      params.require(:activity).permit(:activity_type, :body)
    end
  end
end


