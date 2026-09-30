require "csv"

module Forefront
  # The audit log as CSV, showing each event the way `viewer` sees it on the
  # log page (so contact details stay hidden from non-Admins).
  class AuditEventCsvExport
    HEADERS = [ "When", "Who", "Action", "Record type", "Record", "Changes" ].freeze

    def initialize(events, viewer:)
      @events = events
      @viewer = viewer
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << HEADERS

        @events.each do |event|
          csv << [
            event.created_at,
            event.actor.name,
            event.action.humanize(capitalize: false),
            event.auditable_kind,
            event.auditable_label,
            event.change_lines_for(@viewer).join("; ")
          ]
        end
      end
    end
  end
end
