module Forefront
  class MyWorkController < ApplicationController
    def index
      authorize :my_work, :index?, policy_class: Forefront::MyWorkPolicy
      @my_work = MyWork.new(current_admin)
      @available_tickets = UnassignedPool.visible_to(current_admin, policy_scope(Ticket)).unfinished.order(:created_at).limit(20)
      @available_leads = UnassignedPool.visible_to(current_admin, policy_scope(Lead)).active.order(:created_at).limit(20)
    end
  end
end
