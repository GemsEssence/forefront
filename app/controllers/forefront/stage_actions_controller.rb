module Forefront
  # A Sales person moving a Lead on through one of its stage actions.
  class StageActionsController < ApplicationController
    def create
      lead = Lead.find(params[:lead_id])
      authorize lead, :work?

      result = LeadOperations::StageAction.new(lead: lead, params: stage_action_params, current_admin: current_admin).call

      if result[:success]
        redirect_to lead_path(lead), notice: "#{LeadOperations::StageAction::LABELS[stage_action_params[:kind]]}: done.", status: :see_other
      else
        render_modal_errors "stage_action_modal_lead_#{lead.id}_#{stage_action_params[:kind]}",
                            partial: "forefront/leads/stage_action_form",
                            locals: { lead: lead, kind: stage_action_params[:kind], values: stage_action_params },
                            errors: result[:errors], fallback: lead
      end
    end

    private

    def stage_action_params
      params.require(:stage_action).permit(:kind, :note, :followup_type, :scheduled_for, :ticket_due_at, :actual_amount, :expires_at, :lost_reason_id)
    end
  end
end
