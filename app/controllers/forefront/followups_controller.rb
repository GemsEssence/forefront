module Forefront
  class FollowupsController < ApplicationController
    before_action :find_followupable, only: [:create]
    before_action :set_followup, only: [:update]

    def create
      authorize @followupable, :update?

      result = Forefront::FollowupOperations::Create.new(
        followupable: @followupable,
        params: followup_params,
        current_admin: current_admin
      ).call

      respond_to do |format|
        if result[:success]
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(followups_dom_id(@followupable), partial: 'forefront/followups/list', locals: { followupable: @followupable }),
              turbo_stream.update('flash_messages', partial: 'forefront/followups/flash', locals: { message: 'Followup created.' })
            ]
          end
          format.html { redirect_to @followupable, notice: 'Followup created.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(followups_modal_dom_id(@followupable), partial: 'forefront/followups/form', locals: { followupable: @followupable, admins: Admin.all.order(:name), errors: result[:errors] }),
              turbo_stream.update('flash_messages', partial: 'forefront/followups/flash', locals: { message: result[:errors].join(', ') })
            ]
          end
          format.html { redirect_to @followupable, alert: result[:errors].join(', ') }
        end
      end
    end

    def update
      authorize @followup.followupable, :update?

      result = Forefront::FollowupOperations::Update.new(
        followup: @followup,
        params: followup_update_params,
        current_admin: current_admin
      ).call

      respond_to do |format|
        if result[:success]
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(followups_dom_id(@followup.followupable), partial: 'forefront/followups/list', locals: { followupable: @followup.followupable }),
              turbo_stream.update('flash_messages', partial: 'forefront/followups/flash', locals: { message: 'Followup updated.' })
            ]
          end
          format.html { redirect_to @followup.followupable, notice: 'Followup updated.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(followups_modal_dom_id(@followup.followupable), partial: 'forefront/followups/form', locals: { followupable: @followup.followupable, admins: Admin.all.order(:name), errors: result[:errors], followup: @followup }),
              turbo_stream.update('flash_messages', partial: 'forefront/followups/flash', locals: { message: result[:errors].join(', ') })
            ]
          end
          format.html { redirect_to @followup.followupable, alert: result[:errors].join(', ') }
        end
      end
    end

    private

    def find_followupable
      if params[:ticket_id].present?
        @followupable = Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        @followupable = Lead.find(params[:lead_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def set_followup
      @followup = Forefront::Followup.find(params[:id])
    end

    def followups_dom_id(followupable)
      "followups_#{followupable.class.name.demodulize.underscore}_#{followupable.id}"
    end

    def followups_modal_dom_id(followupable)
      "followup_modal_#{followupable.class.name.demodulize.underscore}_#{followupable.id}"
    end

    def followup_params
      params.require(:followup).permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
    end

    def followup_update_params
      params.require(:followup).permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
    end
  end
end
