module Forefront
  # Raises the time-based Notifications. Schedule it in the host app (every
  # 15 minutes or so), or run `bin/rails forefront:notify` from cron.
  class NotificationSweepJob < ApplicationJob
    queue_as :default

    def perform
      NotificationOperations::Sweep.new.call
    end
  end
end
