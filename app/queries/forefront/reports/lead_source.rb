module Forefront
  module Reports
    # Leads created in the period per Source (and Campaign): how many, how many
    # of those are won, the rate, the won amount, and the days it took.
    class LeadSource < MetricReport
      report key: "lead_source", title: "Lead source", group: :pipeline, roles: TEAM_ROLES,
             filters: %i[source campaign], breakdown: true

      def label_columns
        [ column(:source, "Source", :text), column(:campaign, "Campaign", :text) ]
      end

      def row_keys
        pairs = cohort_rows.map { |row| row.values_at(0, 1) }.uniq
        sources = Source.where(id: pairs.map(&:first)).index_by(&:id)
        campaigns = Campaign.where(id: pairs.map(&:last).compact).index_by(&:id)
        pairs.map { |source_id, campaign_id| [ [ sources[source_id]&.name, campaigns[campaign_id]&.name || "—" ], [ source_id, campaign_id ] ] }
             .sort_by { |labels, _| labels.map(&:to_s) }
      end

      def metrics
        @metrics ||= [
          Metric.new(key: :leads, title: "Leads", format: :count, periodic: true, value: ->(key, ctx) { cohort(key, ctx).size }),
          Metric.new(key: :won, title: "Won", format: :count, periodic: true, value: ->(key, ctx) { won_in(key, ctx).size }),
          Metric.new(key: :rate, title: "Conversion", format: :percent, periodic: true, value: lambda { |key, ctx|
            total = cohort(key, ctx).size
            total.zero? ? nil : won_in(key, ctx).size * 100.0 / total
          }),
          Metric.new(key: :revenue, title: "Revenue", format: :money, periodic: true, value: ->(key, ctx) { won_in(key, ctx).sum { |row| row[4].to_d } }),
          Metric.new(key: :days, title: "Avg days to win", format: :days, periodic: true, value: lambda { |key, ctx|
            mean(won_in(key, ctx).map { |row| (row[5] - row[2]) / 1.day })
          })
        ]
      end

      private

      # Rows are [source_id, campaign_id, created_at, status, actual_amount, won_at],
      # plucked once for the whole period; buckets filter them in memory.
      def cohort_rows
        @cohort_rows ||= context.leads.where(created_at: context.period.times)
                                .pluck(:source_id, :campaign_id, :created_at, :status, :actual_amount, :won_at)
      end

      def cohort(key, ctx)
        times = ctx.period.times
        cohort_rows.select { |row| row[0] == key[0] && row[1] == key[1] && times.cover?(row[2]) }
      end

      def won_in(key, ctx)
        cohort(key, ctx).select { |row| row[3] == "won" }
      end
    end
  end
end
