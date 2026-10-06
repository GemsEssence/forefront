module Forefront
  # A Deadline (CONTEXT.md): the due date by which a Lead is won or lost, or
  # a Ticket resolved or closed. Never further ahead than the Admin-set limit
  # for that kind of record, counted from today. Included by Lead and Ticket.
  module Deadline
    extend ActiveSupport::Concern

    included do
      validate :deadline_within_limit, if: -> { due_at.present? && will_save_change_to_due_at? && deadline_limited? }
    end

    class_methods do
      # Settings#lead_close_within_days / ticket_close_within_days.
      def deadline_limit_days
        Settings.current.public_send("#{model_name.element}_close_within_days")
      end

      def latest_deadline
        Date.current + deadline_limit_days
      end
    end

    # The deadline has passed and the record is still open.
    def deadline_passed?
      overdue?
    end

    private

    # Work System opens (a renewal Ticket due when the subscription ends)
    # takes its own date.
    def deadline_limited?
      !(respond_to?(:created_by) && created_by&.system?)
    end

    def deadline_within_limit
      return if due_at <= self.class.latest_deadline

      errors.add(:due_at, "can't be more than #{self.class.deadline_limit_days} days ahead")
    end
  end
end
