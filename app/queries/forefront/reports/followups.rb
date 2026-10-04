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
                     value: ->(person, _ctx) { overdue_rows.count { |row| row[1] == person.id } }),
          Metric.new(key: :rescheduled, title: "Rescheduled", format: :count, periodic: true, value: lambda { |person, ctx|
            times = ctx.period.times
            reschedules.count { |actor_id, created_at| actor_id == person.id && times.cover?(created_at) }
          })
        ]
      end

      private

      # Rows are [id, assigned_to_id, scheduled_for, status, completed_at].
      def followup_rows
        @followup_rows ||= context.scope.followups.where(scheduled_for: context.period.times)
                                  .pluck(:id, :assigned_to_id, :scheduled_for, :status, :completed_at)
      end

      def overdue_rows
        @overdue_rows ||= context.scope.followups.pending.where("scheduled_for < ?", Time.current)
                                 .pluck(:id, :assigned_to_id, :scheduled_for, :status, :completed_at)
      end

      # [actor_id, created_at] of every date change in the period, read in Ruby (portable JSON).
      def reschedules
        @reschedules ||= AuditEvent.where(action: "updated_followup", created_at: context.period.times)
                                   .pluck(:actor_id, :created_at, :audited_changes)
                                   .select { |_, _, changes| changes.key?("scheduled_for") }
                                   .map { |actor_id, created_at, _| [ actor_id, created_at ] }
      end

      # Scheduled in the period, already come due and not cancelled.
      def due(person, ctx)
        times = ctx.period.times
        now = Time.current
        followup_rows.select do |row|
          row[1] == person.id && times.cover?(row[2]) && row[2] <= now && row[3] != "cancelled"
        end
      end

      def on_time(person, ctx)
        due(person, ctx).select { |row| row[4] && row[4] <= row[2].end_of_day }
      end
    end
  end
end
