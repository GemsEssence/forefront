module Forefront
  module Reports
    # A report built from Metrics. Subclasses define #label_columns (Columns),
    # #row_keys (Array of [labels, row_key]) and #metrics; columns and rows are
    # generated, with a column per bucket and a Total for periodic metrics when
    # the Context has a breakdown. Each bucket's value is computed with the
    # Context narrowed to that bucket's dates.
    class MetricReport < Base
      def columns
        label_columns + metrics.flat_map do |metric|
          next [ column(metric.key, metric.title, metric.format) ] unless broken_down?(metric)

          buckets.map { |label, dates| column(:"#{metric.key}_#{dates.begin.iso8601}", "#{metric.title} · #{label}", metric.format) } +
            [ column(:"#{metric.key}_total", "#{metric.title} · Total", metric.format) ]
        end
      end

      def rows
        row_keys.map do |labels, row_key|
          labels + metrics.flat_map do |metric|
            next [ metric.value.call(row_key, context) ] unless broken_down?(metric)

            buckets.map { |_, dates| metric.value.call(row_key, narrowed(dates)) } + [ metric.value.call(row_key, context) ]
          end
        end
      end

      def label_columns
        raise NotImplementedError
      end

      def row_keys
        raise NotImplementedError
      end

      def metrics
        raise NotImplementedError
      end

      private

      def broken_down?(metric)
        metric.periodic && context.breakdown.present?
      end

      def buckets
        @buckets ||= Buckets.for(context.period.dates, context.breakdown)
      end

      # Memoizes a value per cell, e.g. cell(:due, person.id, ctx.period.dates) { ... },
      # so metrics sharing a base set compute it once.
      def cell(*key)
        (@cells ||= {})[key] ||= yield
      end

      def narrowed(dates)
        context.with_scope(context.scope.with(period: Dashboard::Period.for_dates(dates)))
      end
    end
  end
end
