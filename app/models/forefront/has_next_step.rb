module Forefront
  # The Next step (CONTEXT.md): what the assignee does next on an open
  # record. Included by Lead and Ticket, which each say where theirs comes
  # from (#next_step) and when they're open for work (#open_for_work?).
  module HasNextStep
    extend ActiveSupport::Concern

    Step = Struct.new(:kind, :label, :at, :record, keyword_init: true)

    def pending_followup
      followups.pending.order(:scheduled_for).first
    end

    def needs_next_step?
      open_for_work? && next_step.nil?
    end

    private

    def followup_step(followup)
      Step.new(kind: :followup, label: "#{followup.followup_type} #{customer.name} on #{followup.scheduled_for.strftime("%-d %b %H:%M")}",
               at: followup.scheduled_for, record: followup)
    end
  end
end
