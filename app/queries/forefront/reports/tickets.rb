module Forefront
  module Reports
    # Tickets per category over the period: opened, resolved or closed, how
    # long resolving took, and how many Tickets each Lead needed. Tickets and
    # their resolutions are plucked once and filtered in Ruby, so the queries
    # don't grow with the categories or the buckets.
    class Tickets < MetricReport
      report key: "tickets", title: "Ticket", group: :activity, roles: TEAM_ROLES, filters: %i[campaign], breakdown: true

      FINISHED = %w[resolved closed].freeze

      def label_columns
        [ column(:category, "Category", :text) ]
      end

      # Categories with any Ticket opened or resolved in the period.
      def row_keys
        active = (ticket_rows.map { |row| row[1] } | finished_rows.filter_map { |id, _| tickets_by_id[id]&.at(1) }).sort
        active.map { |category| [ [ Ticket.categories.fetch(category) ], category ] }
      end

      def metrics
        @metrics ||= [
          Metric.new(key: :opened, title: "Opened", format: :count, periodic: true, value: ->(category, ctx) { opened(category, ctx).size }),
          Metric.new(key: :resolved, title: "Resolved or closed", format: :count, periodic: true, value: ->(category, ctx) { finished(category, ctx).size }),
          Metric.new(key: :hours, title: "Avg hours to resolve", format: :hours, periodic: true, value: lambda { |category, ctx|
            mean(finished(category, ctx).map { |id, at| (at - tickets_by_id[id][2]) / 1.hour })
          }),
          Metric.new(key: :per_lead, title: "Tickets per lead", format: :ratio, periodic: true, value: lambda { |category, ctx|
            with_lead = opened(category, ctx).select { |row| row[3] }
            with_lead.empty? ? nil : with_lead.size.to_f / with_lead.map { |row| row[3] }.uniq.size
          })
        ]
      end

      private

      # Rows are [id, category, created_at, lead_id] for every in-scope Ticket
      # opened in the period or resolved in it (so a Ticket opened earlier still
      # has its category and opening time for the hours to resolve).
      def tickets_by_id
        @tickets_by_id ||= begin
          ids = finished_rows.map(&:first)
          scoped = context.tickets
          scoped.where(created_at: context.period.times).or(scoped.where(id: ids))
                .pluck(:id, :category, :created_at, :lead_id).index_by(&:first)
        end
      end

      def ticket_rows
        @ticket_rows ||= tickets_by_id.values.select { |row| context.period.times.cover?(row[2]) }
      end

      # A Ticket resolved, reopened and resolved again in the period counts each resolution (every move into Resolved or Closed).
      # [ticket_id, created_at] of every move into Resolved or Closed in the period
      # on an in-scope Ticket.
      def finished_rows
        @finished_rows ||= begin
          rows = StatusHistory.where(trackable_type: Ticket.name, created_at: context.period.times,
                                     new_status: FINISHED.map { |status| Ticket.statuses.fetch(status) })
                              .pluck(:trackable_id, :created_at)
          in_scope = context.tickets.where(id: rows.map(&:first)).pluck(:id).to_set
          rows.select { |id, _| in_scope.include?(id) }
        end
      end

      def opened_by_category
        @opened_by_category ||= ticket_rows.group_by { |row| row[1] }
      end

      def finished_by_category
        @finished_by_category ||= finished_rows.group_by { |id, _| tickets_by_id[id][1] }
      end

      # The category's Tickets opened, and resolutions, in the cell's period; computed once per cell.
      def opened(category, ctx)
        times = ctx.period.times
        cell(:opened, category, ctx.period.dates) { opened_by_category.fetch(category, []).select { |row| times.cover?(row[2]) } }
      end

      def finished(category, ctx)
        times = ctx.period.times
        cell(:finished, category, ctx.period.dates) { finished_by_category.fetch(category, []).select { |_, at| times.cover?(at) } }
      end
    end
  end
end
