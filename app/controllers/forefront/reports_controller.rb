module Forefront
  # What happened over a period, as tables you can export.
  class ReportsController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :report, :index?, policy_class: Forefront::ReportPolicy
      @reports = Reports.visible_to(current_admin).group_by(&:group)
    end

    def show
      report_class = Reports.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize report_class, :show?, policy_class: Forefront::ReportPolicy
      @context = Reports::Context.from_params(current_admin, params, report_class)
      @report = report_class.new(@context)

      respond_to do |format|
        format.html
        format.csv do
          csv = ReportCsv.new(@report).call
          AuditEvent.record!(actor: current_admin, action: "exported_report", auditable: nil,
                             audited_changes: { "report" => [ nil, report_class.key ], "filters" => [ nil, @context.to_params.to_json ] })
          send_data csv, filename: "#{report_class.key}-#{Date.current.iso8601}.csv", type: "text/csv"
        end
      end
    end
  end
end
