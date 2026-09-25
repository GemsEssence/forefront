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

      if result[:success]
        redirect_back fallback_location: @followupable, notice: "Followup created.", status: :see_other
      else
        redirect_back fallback_location: @followupable, alert: result[:errors].join(", "), status: :see_other
      end
    end

    def update
      authorize @followup.followupable, :update?

      result = Forefront::FollowupOperations::Update.new(
        followup: @followup,
        params: followup_update_params,
        current_admin: current_admin
      ).call

      if result[:success]
        redirect_back fallback_location: @followup.followupable, notice: "Followup updated.", status: :see_other
      else
        redirect_back fallback_location: @followup.followupable, alert: result[:errors].join(", "), status: :see_other
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

    def followup_params
      params.require(:followup).permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
    end

    def followup_update_params
      params.require(:followup).permit(:assigned_to_id, :followup_type, :scheduled_for, :status, :outcome)
    end
  end
end
