module Forefront
  # The signed-in Staff member's own Notifications.
  class NotificationsController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      @notifications = mine.includes(:subject).recent.limit(100)
    end

    # Opening one marks it read and goes to what it's about.
    def show
      notification = mine.find(params[:id])
      NotificationOperations::MarkRead.new(notifications: Notification.where(id: notification.id)).call
      redirect_to notification.subject
    end

    def read_all
      NotificationOperations::MarkRead.new(notifications: mine).call
      redirect_to notifications_path, notice: "All caught up."
    end

    private

    def mine
      Notification.where(recipient: current_admin)
    end
  end
end
