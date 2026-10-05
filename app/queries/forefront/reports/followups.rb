module Forefront
  module Reports
    # Followup discipline per person over the period, the same rules as the
    # Performance page: due by now, done on the day, done late, overdue now,
    # and how often they moved a Followup's date. Followups and reschedule
    # events are plucked once and filtered in Ruby, so the queries don't grow
    # with the people or the buckets.
    class Followups < MetricReport
      report key: "followups", title: "Follow-up", group: :activity, breakdown: true

      def label_columns
        [ column(:person, "Person", :text) ]
      end

      def row_keys
        context.scope.rows.map { |person| [ [ person.name ], person ] }
      end

      def metrics
        @metrics ||= [
          Metric.new(key: :due, title: "Due", format: :count, periodic: true, value: ->(person, ctx) { due(person, ctx).size }),
          Metric.new(key: :on_time, title: "Done on time", format: :count, periodic: true, value: ->(person, ctx) { on_time(person, ctx).size }),
          Metric.new(key: :late, title: "Done late", format: :count, periodic: true,
                     value: ->(person, ctx) { due(person, ctx).count { |row| row[4] } - on_time(person, ctx).size }),
          Metric.new(key: :overdue, title: "Overdue now", format: :count, periodic: false,
                     value: ->(person, _ctx) { overdue_counts.fetch(person.id, 0) }),
          Metric.new(key: :rescheduled, title: "Rescheduled", format: :count, periodic: true, value: lambda { |person, ctx|
            times = ctx.period.times
            reschedules.fetch(person.id, []).count { |created_at| times.cover?(created_at) }
          })
        ]
      end

      private

      # Rows are [id, assigned_to_id, scheduled_for, status, completed_at].
      def followup_rows
        @followup_rows ||= context.scope.followups.where(scheduled_for: context.period.times)
                                  .pluck(:id, :assigned_to_id, :scheduled_for, :status, :completed_at)
      end

      # The period's Followups already come due and not cancelled, grouped by person.
      def due_by_person
        @due_by_person ||= begin
          now = Time.current
          followup_rows.select { |row| row[2] <= now && row[3] != "cancelled" }.group_by { |row| row[1] }
        end
      end

      def overdue_counts
        @overdue_counts ||= context.scope.followups.pending.where("scheduled_for < ?", Time.current).pluck(:assigned_to_id).tally
      end

      # created_at of every date change in the period, per actor, read in Ruby (portable JSON).
      def reschedules
        @reschedules ||= AuditEvent.where(action: "updated_followup", created_at: context.period.times)
                                   .pluck(:actor_id, :created_at, :audited_changes)
                                   .select { |_, _, changes| changes.key?("scheduled_for") }
                                   .group_by(&:first).transform_values { |events| events.map { |event| event[1] } }
      end

      # Scheduled in the cell's period, already come due and not cancelled; computed once per cell.
      def due(person, ctx)
        times = ctx.period.times
        cell(:due, person.id, ctx.period.dates) { due_by_person.fetch(person.id, []).select { |row| times.cover?(row[2]) } }
      end

      def on_time(person, ctx)
        cell(:on_time, person.id, ctx.period.dates) { due(person, ctx).select { |row| row[4] && row[4] <= row[2].end_of_day } }
      end
    end
  end
end
