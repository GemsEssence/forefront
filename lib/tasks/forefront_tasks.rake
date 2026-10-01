namespace :forefront do
  desc "Raise Forefront's time-based alerts (unassigned, stale, unanswered reveals, overdue installments)"
  task notify: :environment do
    Forefront::NotificationSweepJob.perform_now
  end
end
