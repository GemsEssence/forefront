module Forefront
  # The Performance page (docs/superpowers/specs/2026-10-03-performance-dashboard-design.md):
  # one row per person (or per team, for an Admin), each a Scope narrowed to
  # that row's people, with one value per column.
  class Performance
    Column = Struct.new(:key, :title, :format, :metric, :denominator_metric, keyword_init: true)
    Row = Struct.new(:label, :person, :scope, :values, keyword_init: true)

    # A rate shown as "x of y (z%)". Team rows add the parts, then divide.
    Rate = Struct.new(:numerator, :denominator) do
      def percent
        denominator.to_i.zero? ? nil : numerator * 100.0 / denominator
      end

      def +(other)
        Rate.new(numerator + other.numerator, denominator + other.denominator)
      end
    end

    COLUMNS = [].freeze

    attr_reader :scope

    def initialize(scope)
      @scope = scope
    end

    def columns
      COLUMNS
    end

    def rows
      scope.rows.map { |person| build_row(person.name, person, scope.for_member(person)) }
    end

    private

    def build_row(label, person, row_scope)
      Row.new(label: label, person: person, scope: row_scope,
              values: columns.to_h { |column| [ column.key, public_send("value_#{column.key}", row_scope) ] })
    end
  end
end
