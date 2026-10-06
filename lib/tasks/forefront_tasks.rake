namespace :forefront do
  desc "Raise Forefront's time-based alerts (unassigned, stale, unanswered reveals, overdue installments)"
  task notify: :environment do
    Forefront::NotificationSweepJob.perform_now
  end

  desc "Pull subscription expiry dates from each Product's application and open or resolve Renewal tickets"
  task pull_expiries: :environment do
    Forefront::ExpiryPullJob.perform_now
  end
end
