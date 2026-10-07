module Forefront
  # Done on a Followup: its outcome and what comes next.
  class CompletionsController < ApplicationController
    def create
      followup = Followup.find(params[:followup_id])
      record = followup.followupable
      authorize record, :work_on?

      result = FollowupOperations::Complete.new(followup: followup, params: completion_params, current_admin: current_admin).call

      if result[:success]
        redirect_back fallback_location: record, notice: "Done. Next step recorded.", status: :see_other
      else
        render_modal_errors "followup_done_modal_#{followup.id}",
                            partial: "forefront/followups/complete_form",
                            locals: { followup: followup, values: completion_params },
                            errors: result[:errors], fallback: record
      end
    end

    private

    def completion_params
      params.require(:completion).permit(:outcome, :next, :followup_type, :scheduled_for, :kind, :ticket_due_at, :actual_amount, :expires_at,
                                         :lost_reason_id, :note, :status)
    end
  end
end
