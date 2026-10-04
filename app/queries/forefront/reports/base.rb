module Forefront
  module Reports
    # A report: a title, who may open it, its columns, and its rows for a
    # Context. Subclasses call `report(...)` and define #columns and #rows.
    class Base
      class << self
        attr_reader :key, :title, :group, :roles, :filters

        def report(key:, title:, group:, roles: ALL_ROLES, filters: [], breakdown: false)
          @key = key
          @title = title
          @group = group
          @roles = roles
          @filters = filters
          @breakdown = breakdown
        end

        def breakdown?
          @breakdown == true
        end
      end

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def columns
        raise NotImplementedError
      end

      def rows
        raise NotImplementedError
      end

      private

      def column(key, title, format)
        Column.new(key: key, title: title, format: format)
      end

      def mean(values)
        values.empty? ? nil : values.sum.fdiv(values.size)
      end
    end
  end
end
