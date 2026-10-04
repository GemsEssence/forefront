module Forefront
  module Reports
    # Open Leads now, by the month they're due to close and by stage: what's
    # coming in and when. Past-due and undated Leads get their own rows.
    class PipelineForecast < Base
      report key: "pipeline_forecast", title: "Pipeline and forecast", group: :pipeline, roles: TEAM_ROLES,
             filters: %i[source campaign]

      STAGES = Dashboard::Metrics::ACTIVE_STAGES

      def columns
        [ column(:month, "Due", :text) ] +
          STAGES.flat_map { |stage| [ column(stage.to_sym, stage.humanize, :count), column(:"#{stage}_value", "#{stage.humanize} value", :money) ] } +
          [ column(:total, "Total", :count), column(:total_value, "Total value", :money) ]
      end

      def rows
        today = Date.current
        leads = context.leads.active.pluck(:due_at, :status, :estimated_amount)
        grouped = leads.group_by do |due, _, _|
          if due.nil? then [ 2, nil ]
          elsif due < today then [ 0, nil ]
          else [ 1, due.beginning_of_month ]
          end
        end
        grouped.sort_by { |(order, month), _| [ order, month || today ] }.map do |(order, month), group|
          label = { 0 => "Overdue", 2 => "No date" }[order] || month.strftime("%b %Y")
          [ label ] + STAGES.flat_map { |stage| stage_cells(group, stage) } + [ group.size, total_amount(group) ]
        end
      end

      private

      def stage_cells(group, stage)
        in_stage = group.select { |_, status, _| status == stage }
        [ in_stage.size, total_amount(in_stage) ]
      end

      def total_amount(group)
        group.sum { |_, _, amount| amount.to_d }
      end
    end
  end
end
