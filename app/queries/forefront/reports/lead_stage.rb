module Forefront
  module Reports
    # Open Leads per stage now: how many, their expected value, and how long
    # they've sat in that stage (since the last move into it, or creation).
    class LeadStage < Base
      report key: "lead_stage", title: "Lead stage", group: :pipeline, filters: %i[source campaign]

      def columns
        [ column(:stage, "Stage", :text), column(:open, "Open leads", :count),
          column(:value, "Expected value", :money), column(:days, "Avg days in stage", :days) ]
      end

      def rows
        leads = context.leads.active
        entered = StatusHistory.where(trackable_type: Lead.name, trackable_id: leads.select(:id))
                               .group(:trackable_id, :new_status).maximum(:created_at)
        Dashboard::Metrics::ACTIVE_STAGES.map do |stage|
          in_stage = leads.where(status: stage).pluck(:id, :created_at, :estimated_amount)
          days = in_stage.map { |id, created, _| (Time.current - (entered[[ id, Lead.statuses.fetch(stage) ]] || created)) / 1.day }
          [ stage.humanize, in_stage.size, in_stage.sum { |_, _, amount| amount.to_d }, mean(days) ]
        end
      end
    end
  end
end
