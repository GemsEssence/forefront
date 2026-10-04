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
        pairs = context.leads.where(created_at: context.period.times).distinct.pluck(:source_id, :campaign_id)
        sources = Source.where(id: pairs.map(&:first)).index_by(&:id)
        campaigns = Campaign.where(id: pairs.map(&:last).compact).index_by(&:id)
        pairs.map { |source_id, campaign_id| [ [ sources[source_id]&.name, campaigns[campaign_id]&.name || "—" ], [ source_id, campaign_id ] ] }
             .sort_by { |labels, _| labels.map(&:to_s) }
      end

      def metrics
        [
          Metric.new(key: :leads, title: "Leads", format: :count, periodic: true, value: ->(key, ctx) { cohort(key, ctx).count }),
          Metric.new(key: :won, title: "Won", format: :count, periodic: true, value: ->(key, ctx) { cohort(key, ctx).won.count }),
          Metric.new(key: :rate, title: "Conversion", format: :percent, periodic: true, value: lambda { |key, ctx|
            total = cohort(key, ctx).count
            total.zero? ? nil : cohort(key, ctx).won.count * 100.0 / total
          }),
          Metric.new(key: :revenue, title: "Revenue", format: :money, periodic: true, value: ->(key, ctx) { cohort(key, ctx).won.sum(:actual_amount) }),
          Metric.new(key: :days, title: "Avg days to win", format: :days, periodic: true, value: lambda { |key, ctx|
            mean(cohort(key, ctx).won.pluck(:created_at, :won_at).map { |created, won| (won - created) / 1.day })
          })
        ]
      end

      private

      def cohort(key, ctx)
        ctx.leads.where(created_at: ctx.period.times, source_id: key[0], campaign_id: key[1])
      end
    end
  end
end
