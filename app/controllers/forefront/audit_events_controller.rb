module Forefront
  class AuditEventsController < ApplicationController
    helper_method :filter_params

    def index
      authorize AuditEvent
      visible_events = policy_scope(AuditEvent)
      filtered_events = AuditEventServices::Filter.new(scope: visible_events, filters: filter_params).call
                                                  .includes(:actor).recent

      respond_to do |format|
        format.html do
          @audit_events = filtered_events.page(params[:page])
          load_filter_choices(visible_events)
        end
        format.csv do
          send_data AuditEventCsvExport.new(filtered_events, viewer: current_admin).call,
                    filename: "audit-log-#{Date.current.iso8601}.csv"
        end
      end
    end

    private

    def load_filter_choices(visible_events)
      @actors = Admin.where(id: visible_events.select(:actor_id)).order(:name)
      @auditable_types = visible_events.where.not(auditable_type: nil).distinct.pluck(:auditable_type).sort
      @event_actions = visible_events.distinct.pluck(:action).sort
    end

    def filter_params
      params.permit(:actor_id, :auditable_type, :event_action, :from, :to)
    end
  end
end
