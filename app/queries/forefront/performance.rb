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

    COLUMNS = [
      Column.new(key: :records_claimed, title: "Records claimed", format: :count, metric: "claims"),
      Column.new(key: :avg_time_to_claim, title: "Avg time to claim", format: :hours, metric: "claims"),
      Column.new(key: :ticket_to_lead, title: "Ticket → lead", format: :rate, metric: "enquiries_converted", denominator_metric: "enquiries_handled"),
      Column.new(key: :lead_to_win, title: "Lead → win", format: :rate, metric: "won", denominator_metric: "leads_closed")
    ].freeze

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

    def value_records_claimed(row_scope)
      Dashboard::Metrics.claims(row_scope).count
    end

    # Hours from the record entering the pool (its creation) to being taken.
    def value_avg_time_to_claim(row_scope)
      waits = Dashboard::Metrics.claims(row_scope).includes(:assignable).map { |claim| (claim.created_at - claim.assignable.created_at) / 3600.0 }
      waits.empty? ? nil : waits.sum / waits.size
    end

    def value_ticket_to_lead(row_scope)
      rate(row_scope, "enquiries_converted", "enquiries_handled")
    end

    def value_lead_to_win(row_scope)
      rate(row_scope, "won", "leads_closed")
    end

    private

    def rate(row_scope, numerator, denominator)
      Rate.new(Dashboard::Metrics.fetch(numerator).relation(row_scope).count,
               Dashboard::Metrics.fetch(denominator).relation(row_scope).count)
    end

    def build_row(label, person, row_scope)
      Row.new(label: label, person: person, scope: row_scope,
              values: columns.to_h { |column| [ column.key, public_send("value_#{column.key}", row_scope) ] })
    end
  end
end
