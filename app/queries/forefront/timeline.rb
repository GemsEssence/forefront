module Forefront
  # A record's Timeline (CONTEXT.md: Audit event): everything that happened
  # to one Lead or Ticket, newest first. Notes are shown live (so they can
  # still be edited); stage, status and assignment changes come with their
  # notes; everything else comes from the record's Audit events.
  class Timeline
    # rank breaks ties within one second: created, then assigned, then the rest.
    Entry = Struct.new(:at, :who, :headline, :detail, :activity, :rank, keyword_init: true)

    # Already covered by a live note, a StatusHistory or an Assignment.
    COVERED_ACTIONS = %w[added_activity edited_activity changed_status assigned updated_followup].freeze

    attr_reader :record, :viewer

    def initialize(record, viewer:)
      @record = record
      @viewer = viewer
    end

    def entries
      @entries ||= (notes + status_changes + assignments + events + opened_tickets).sort_by { |entry| [ -entry.at.to_f, -(entry.rank || 3) ] }
    end

    private

    def notes
      record.activities.includes(:created_by).map { |activity| Entry.new(at: activity.created_at, who: activity.created_by, activity: activity) }
    end

    def status_changes
      record.status_histories.includes(:changed_by).map do |history|
        Entry.new(at: history.created_at, who: history.changed_by, headline: "#{history.old_status.presence || "Start"} → #{history.new_status}", detail: history.note)
      end
    end

    def assignments
      record.assignments.includes(:to_user, :from_user, :changed_by).map do |assignment|
        from = assignment.from_user ? " (from #{assignment.from_user.name})" : ""
        Entry.new(at: assignment.created_at, who: assignment.changed_by, headline: "Assigned to #{assignment.to_user.name}#{from}", detail: assignment.note, rank: 1)
      end
    end

    # Demo and Proposal tickets opened under a Lead.
    def opened_tickets
      return [] unless record.is_a?(Lead)

      record.tickets.includes(:created_by).map { |ticket| Entry.new(at: ticket.created_at, who: ticket.created_by, headline: "Opened ticket: #{ticket.title}", detail: "due #{ticket.due_at&.strftime("%-d %b")}") }
    end

    def events
      scope = AuditEvent.where(auditable: record).where.not(action: COVERED_ACTIONS)
      scope = scope.or(AuditEvent.where(auditable: record.customer, action: "revealed_contact")) if record.respond_to?(:customer)
      scope.includes(:actor).map { |event| Entry.new(at: event.created_at, who: event.actor, rank: (event.action == "created" ? 0 : 3), **words_for(event)) }
    end

    def words_for(event)
      changes = event.audited_changes.to_h
      last = ->(field) { changes[field]&.last }
      case event.action
      when "created" then { headline: "Created" }
      when "scheduled_followup"
        { headline: "Scheduled a #{last["followup_type"].to_s.downcase} for #{time(last["scheduled_for"])}", detail: last["outcome"] }
      when "completed_followup" then { headline: "Completed #{last["followup"]}", detail: last["outcome"] }
      when "marked_awaiting_customer" then { headline: "Marked awaiting customer" }
      when "customer_responded" then { headline: "Customer responded" }
      when "converted" then { headline: "Converted to lead #{last["lead"]}" }
      when "reopened" then { headline: "Reopened", detail: "assigned to #{last["assigned_to"] || "the pool"}" }
      when "extended_deadline" then { headline: "Deadline moved #{date(changes["due_at"]&.first)} → #{date(last["due_at"])}", detail: last["note"] }
      when "recorded_payment" then { headline: "Recorded payment of #{money(last["total_amount"])}" }
      when "added_installment" then { headline: "Added an installment of #{money(last["amount"])}", detail: "due #{date(last["due_on"])}" }
      when "recorded_receipt" then { headline: "Received #{money(last["amount"])}", detail: [ last["payment_method"], last["reference"], date(last["received_on"]) ].compact_blank.join(" · ") }
      when "attached_receipt" then { headline: "Attached a receipt from the app", detail: last["receipt"] }
      when "recorded_lead_share" then { headline: "Shared the credit", detail: last["shares"] }
      when "deleted_activity" then { headline: "Deleted a note", detail: changes["body"]&.first }
      when "revealed_contact" then { headline: "Revealed the customer's contact details" }
      when "updated" then { headline: "Edited", detail: event.change_lines_for(viewer).join("; ") }
      else { headline: event.action.humanize, detail: event.change_lines_for(viewer).join("; ").presence }
      end
    end

    def time(value)
      Time.zone.parse(value.to_s)&.strftime("%-d %b %H:%M") || value.to_s
    end

    def date(value)
      Date.parse(value.to_s).strftime("%-d %b %Y")
    rescue ArgumentError, TypeError
      value.to_s
    end

    def money(value)
      return "—" if value.blank?

      @money ||= Object.new.extend(ActionView::Helpers::NumberHelper, CurrencyHelper)
      @money.format_money(value)
    end
  end
end
