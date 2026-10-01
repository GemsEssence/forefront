module Forefront
  # The Unassigned pool: work nobody has yet, as much of it as the viewer
  # may see (UnassignedPool).
  class UnassignedController < ApplicationController
    def index
      @tickets = UnassignedPool.visible_to(current_admin, policy_scope(Ticket))
                               .where.not(status: %w[resolved closed]).includes(:customer, :product).order(:created_at)
      @leads = UnassignedPool.visible_to(current_admin, policy_scope(Lead)).active.includes(:customer, :product).order(:created_at)
    end
  end
end
