module Forefront
  # The reports Forefront offers (docs/superpowers/specs/2026-10-04-reports-design.md).
  # Classes are named, not loaded, here so Zeitwerk loads each on first use.
  module Reports
    ALL_ROLES = %w[sales_person manager admin].freeze
    TEAM_ROLES = %w[manager admin].freeze
    BREAKDOWNS = %w[day week month quarter].freeze

    @registry = {}

    def self.register(key, class_name)
      raise ArgumentError, "report #{key} already registered" if @registry.key?(key.to_s)

      @registry[key.to_s] = class_name
    end

    def self.all
      @registry.values.map(&:constantize)
    end

    def self.find(key)
      @registry[key.to_s]&.constantize
    end

    def self.visible_to(admin)
      all.select { |report| report.roles.include?(admin.role) }
    end

    register "lead_stage", "Forefront::Reports::LeadStage"
    register "lead_source", "Forefront::Reports::LeadSource"
    register "pipeline_forecast", "Forefront::Reports::PipelineForecast"
    register "conversion_funnel", "Forefront::Reports::ConversionFunnel"
  end
end
