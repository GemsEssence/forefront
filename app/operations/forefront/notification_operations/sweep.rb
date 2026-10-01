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
        stale_work
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

      # Assigned work with no Action within the limit of its assignment or
      # its last Action, or past its due date with none since (CONTEXT.md:
      # stale). A Lead waiting on the Customer isn't stale while its Followup
      # is still ahead. The assignee and their Manager are told.
      def stale_work
        limit = settings.stale_after_hours
        (Ticket.unfinished.where.not(assigned_to_id: nil).to_a + Lead.active.where.not(assigned_to_id: nil).to_a).each do |record|
          next if waiting_on_customer?(record)

          last_action = AuditEvent.actions.where(auditable: record).maximum(:created_at)
          last_touch = [ assigned_at(record), last_action ].compact.max

          if last_touch < now - limit.hours
            notify_stale(record, "since-#{last_touch.to_i}", "No action on #{record.title} for #{limit} hours")
          elsif record.due_at && record.due_at < now.to_date && (last_action.nil? || last_action < record.due_at.beginning_of_day)
            notify_stale(record, "due-#{record.due_at}", "#{record.title} was due #{record.due_at.strftime("%-d %b")} with no action since")
          end
        end
      end

      def waiting_on_customer?(record)
        record.is_a?(Lead) && record.awaiting_customer? && record.next_followup&.scheduled_for&.>(now)
      end

      def assigned_at(record)
        record.assignments.where(to_user_id: record.assigned_to_id).maximum(:created_at) || record.created_at
      end

      def notify_stale(record, key, message)
        assignee = record.assigned_to
        Notify.new(kind: "stale", subject: record, recipients: [ assignee, assignee.manager ].compact, key: key, message: message).call
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
