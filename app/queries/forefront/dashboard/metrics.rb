# app/queries/forefront/dashboard/metrics.rb
module Forefront
  module Dashboard
    # Every number on a dashboard is a Metric: a relation built from a Scope
    # (and optionally a slice, such as a stage). The dashboard shows its count
    # or a sum over it, and /dashboard/metrics/:key lists the same relation's
    # records, so a number and its list can't disagree.
    module Metrics
      ALL_ROLES = %w[sales_person manager admin].freeze
      TEAM_ROLES = %w[manager admin].freeze

      Metric = Struct.new(:key, :title, :kind, :roles, :periodic, :build, keyword_init: true) do
        def relation(scope, slice = nil)
          build.call(scope, slice)
        end

        def open_to?(admin)
          roles.include?(admin.role)
        end
      end

      @registry = {}

      def self.define(key, title:, kind:, roles: ALL_ROLES, periodic: false, &build)
        @registry[key.to_s] = Metric.new(key: key.to_s, title: title, kind: kind, roles: roles, periodic: periodic, build: build)
      end

      def self.fetch(key)
        @registry.fetch(key.to_s)
      end

      def self.find(key)
        @registry[key.to_s]
      end

      # Action strip
      define :overdue_followups, title: "Overdue Followups", kind: :followups do |scope, _|
        scope.followups.pending.where("scheduled_for < ?", Time.current)
      end

      define :followups_due_today, title: "Followups due today", kind: :followups do |scope, _|
        scope.followups.pending.where(scheduled_for: Time.current..Time.current.end_of_day)
      end

      define :newly_assigned, title: "Newly assigned", kind: :assignments, periodic: true do |scope, _|
        scope.assignments.where(created_at: scope.period.times)
      end
    end
  end
end
