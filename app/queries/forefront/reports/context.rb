module Forefront
  module Reports
    # The filters a report runs with: the dashboards' Scope (period, Product,
    # Manager/team, person — never wider than the viewer may see) plus the
    # report's own optional Source, Campaign and breakdown.
    Context = Struct.new(:scope, :source_id, :campaign_id, :breakdown, keyword_init: true) do
      def self.from_params(viewer, params, report_class)
        scope = Dashboard::Scope.from_params(viewer, params)
        source = Dashboard::Scope.scalar(params[:source_id]) if report_class.filters.include?(:source)
        campaign = Dashboard::Scope.scalar(params[:campaign_id]) if report_class.filters.include?(:campaign)
        breakdown = Dashboard::Scope.scalar(params[:breakdown]) if report_class.breakdown?
        new(scope: scope,
            source_id: (source.to_i if source.present? && Source.exists?(id: source)),
            campaign_id: (campaign.to_i if campaign.present? && Campaign.exists?(id: campaign)),
            breakdown: (breakdown if BREAKDOWNS.include?(breakdown)))
      end

      def period
        scope.period
      end

      def with_scope(new_scope)
        self.class.new(scope: new_scope, source_id: source_id, campaign_id: campaign_id, breakdown: breakdown)
      end

      def leads
        relation = scope.leads
        relation = relation.where(source_id: source_id) if source_id
        campaign_id ? relation.where(campaign_id: campaign_id) : relation
      end

      def tickets
        campaign_id ? scope.tickets.where(campaign_id: campaign_id) : scope.tickets
      end

      def to_params
        scope.to_params.merge(source_id: source_id, campaign_id: campaign_id, breakdown: breakdown).compact
      end
    end
  end
end
