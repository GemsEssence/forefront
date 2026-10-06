module Forefront
  # Bringing a Lost Lead back, from the Reopen dialog on the Lead page.
  class ReopensController < ApplicationController
    def create
      lead = Lead.find(params[:lead_id])
      authorize lead, :reopen?

      result = LeadOperations::Reopen.new(lead: lead, params: reopen_params, current_admin: current_admin).call

      if result[:success]
        redirect_to lead_path(lead), notice: "Lead reopened.", status: :see_other
      else
        render_modal_errors helpers.modal_id(:reopen, lead),
                            partial: "forefront/leads/reopen_form",
                            locals: { lead: lead, values: reopen_params },
                            errors: result[:errors], fallback: lead
      end
    end

    private

    def reopen_params
      params.require(:reopen).permit(:assigned_to_id, :note)
    end
  end
end
