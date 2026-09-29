module Forefront
  class AuditEventsController < ApplicationController
    def index
      authorize AuditEvent
      @audit_events = policy_scope(AuditEvent).includes(:actor).recent.page(params[:page])
    end
  end
end
