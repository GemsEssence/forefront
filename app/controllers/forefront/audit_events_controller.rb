module Forefront
  class AuditEventsController < ApplicationController
    def index
      authorize AuditEvent
      visible_events = policy_scope(AuditEvent)
      @audit_events = AuditEventServices::Filter.new(scope: visible_events, filters: filter_params).call
                                                .includes(:actor).recent.page(params[:page])

      @actors = Admin.where(id: visible_events.select(:actor_id)).order(:name)
      @auditable_types = visible_events.where.not(auditable_type: nil).distinct.pluck(:auditable_type).sort
      @event_actions = visible_events.distinct.pluck(:action).sort
    end

    private

    def filter_params
      params.permit(:actor_id, :auditable_type, :event_action, :from, :to)
    end
  end
end
