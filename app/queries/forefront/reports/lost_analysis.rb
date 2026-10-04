# app/queries/forefront/reports/lost_analysis.rb
module Forefront
  module Reports
    # Leads lost in the period, per Lost reason: how many, the value lost, the
    # stage they were usually lost at, and who and which Source lose most.
    class LostAnalysis < Base
      report key: "lost_analysis", title: "Lost analysis", group: :pipeline, roles: TEAM_ROLES, filters: %i[source campaign]

      def columns
        [ column(:reason, "Lost reason", :text), column(:count, "Leads lost", :count), column(:value, "Value lost", :money),
          column(:stage, "Usual stage at loss", :text), column(:person, "Top person", :text), column(:source, "Top source", :text) ]
      end

      def rows
        losses = StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch("lost"), created_at: context.period.times,
                                     trackable_id: context.leads.select(:id))
        # Ordered by time, so a Lead lost more than once keeps the stage of its latest loss.
        stage_at_loss = losses.order(:created_at).pluck(:trackable_id, :old_status).to_h
        leads = Lead.where(id: stage_at_loss.keys).includes(:lost_reason, :assigned_to, :source)
        leads.group_by(&:lost_reason).sort_by { |reason, group| [ -group.size, reason&.name.to_s ] }.map do |reason, group|
          [ reason&.name || "No reason", group.size, group.sum { |lead| lead.estimated_amount.to_d },
            most_common(group.map { |lead| stage_at_loss[lead.id] }), most_common(group.map { |lead| lead.assigned_to&.name }),
            most_common(group.map { |lead| lead.source&.name }) ]
        end
      end

      private

      def most_common(values)
        values.compact.tally.min_by { |value, count| [ -count, value.to_s ] }&.first
      end
    end
  end
end
