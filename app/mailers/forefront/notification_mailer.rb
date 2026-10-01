module Forefront
  # One email per Notification whose kind is switched on in Settings.
  class NotificationMailer < ApplicationMailer
    layout false

    def alert(notification)
      @notification = notification
      mail(to: notification.recipient.email, from: Forefront.mailer_sender, subject: notification.message)
    end
  end
end
