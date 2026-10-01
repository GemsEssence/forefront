module Forefront
  module NotificationOperations
    # The time-based alerts (CONTEXT.md: Notification), raised by a check the
    # host app runs on a schedule (NotificationSweepJob, or the
    # forefront:notify rake task). Each alert is raised once, so running it
    # often is safe. Limits come from the Settings page.
    class Sweep
      def initialize(now: Time.current, settings: Settings.current)
        @now = now
        @settings = settings
      end

      def call
        still_unassigned
        unanswered_reveals
        overdue_installments
      end

      private

      attr_reader :now, :settings

      def handing_out_work
        Admin.people.where(role: %w[admin manager])
      end

      def still_unassigned
        hours = settings.unassigned_alert_after_hours
        cutoff = now - hours.hours
        work = Ticket.unfinished.where(assigned_to_id: nil, created_at: ..cutoff).to_a +
               Lead.active.where(assigned_to_id: nil, created_at: ..cutoff).to_a
        work.each do |record|
          Notify.new(kind: "still_unassigned", subject: record, recipients: handing_out_work,
                     message: "Still unassigned after #{hours} hours: #{record.title}").call
        end
      end

      # Admins, and the revealer's Manager; a Manager's own reveal goes to Admins.
      def unanswered_reveals
        cutoff = now - settings.reveal_action_within_minutes.minutes
        ContactReveal.includes(:admin, :customer).where(created_at: ..cutoff).find_each do |reveal|
          next if reveal.answered? || Notification.exists?(kind: "unanswered_reveal", dedupe_key: reveal.id.to_s)

          recipients = Admin.people.where(role: "admin").to_a
          recipients << reveal.admin.manager if reveal.admin.manager
          Notify.new(kind: "unanswered_reveal", subject: reveal.customer, recipients: recipients.uniq, key: reveal.id,
                     message: "#{reveal.admin.name} revealed #{reveal.customer.name}'s contact details at " \
                              "#{reveal.created_at.strftime("%-d %b %H:%M")} and hasn't recorded what they did").call
        end
      end

      def overdue_installments
        cutoff = now.to_date - settings.installment_overdue_after_days.days
        Installment.pending.where(due_on: ..cutoff).includes(payment: { lead: [ :assigned_to, :created_by ] }).find_each do |installment|
          lead = installment.payment.lead
          Notify.new(kind: "installment_overdue", subject: lead, recipients: [ lead.assigned_to || lead.created_by ], key: "installment-#{installment.id}",
                     message: "Installment of #{money(installment.amount)} due #{installment.due_on.strftime("%-d %b")} on #{lead.title} is unpaid").call
        end
      end

      def money(amount)
        @money ||= Object.new.extend(ActionView::Helpers::NumberHelper, CurrencyHelper)
        @money.format_money(amount)
      end
    end
  end
end
