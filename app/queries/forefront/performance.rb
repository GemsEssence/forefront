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
      Column.new(key: :lead_to_win, title: "Lead → win", format: :rate, metric: "won", denominator_metric: "leads_closed"),
      Column.new(key: :demos_done, title: "Demos done", format: :count, metric: "demos"),
      Column.new(key: :revenue_collected, title: "Revenue collected", format: :money, metric: "receipts_credited"),
      Column.new(key: :shared_revenue, title: "Shared revenue", format: :money, metric: "receipts_shared"),
      Column.new(key: :target_achievement, title: "Target achievement", format: :percent, metric: "target_credited"),
      Column.new(key: :collected_vs_target, title: "Collected vs target", format: :percent, metric: "receipts_credited"),
      Column.new(key: :avg_deal_size, title: "Avg deal size", format: :money, metric: "won"),
      Column.new(key: :avg_sales_cycle, title: "Avg sales cycle", format: :days, metric: "won"),
      Column.new(key: :followup_discipline, title: "Follow-up discipline", format: :rate, metric: "followups_on_time", denominator_metric: "followups_due"),
      Column.new(key: :overdue_now, title: "Overdue now", format: :count, metric: "overdue_followups")
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

    def value_demos_done(row_scope)
      Dashboard::Metrics.fetch(:demos).relation(row_scope).count
    end

    def value_revenue_collected(row_scope)
      credited(Dashboard::Metrics.fetch(:receipts_credited).relation(row_scope), row_scope)
    end

    def value_shared_revenue(row_scope)
      credited(Dashboard::Metrics.fetch(:receipts_shared).relation(row_scope), row_scope)
    end

    # The Targets page's rule (won amounts), for amount Targets running today.
    def value_target_achievement(row_scope)
      targets = amount_targets(row_scope)
      goal = targets.sum(&:goal_value)
      goal.zero? ? nil : targets.sum(&:achieved_value) * 100 / goal
    end

    # Money received against the same goals.
    def value_collected_vs_target(row_scope)
      goal = amount_targets(row_scope).sum(&:goal_value)
      goal.zero? ? nil : value_revenue_collected(row_scope) * 100 / goal
    end

    def value_avg_deal_size(row_scope)
      won = Dashboard::Metrics.fetch(:won).relation(row_scope)
      count = won.count
      count.zero? ? nil : won.sum(:actual_amount) / count
    end

    # Days from created to won, worked out in Ruby (portable SQL).
    def value_avg_sales_cycle(row_scope)
      days = Dashboard::Metrics.fetch(:won).relation(row_scope).pluck(:created_at, :won_at).map { |created, won| (won - created) / 1.day }
      days.empty? ? nil : days.sum / days.size
    end

    def value_followup_discipline(row_scope)
      rate(row_scope, "followups_on_time", "followups_due")
    end

    def value_overdue_now(row_scope)
      Dashboard::Metrics.fetch(:overdue_followups).relation(row_scope).count
    end

    private

    def amount_targets(row_scope)
      row_scope.current_targets.select(&:amount?)
    end

    # Each Receipt's amount times the row's people's combined share of its Lead.
    def credited(receipts, row_scope)
      people = row_scope.people_ids
      receipts.includes(payment: { lead: { lead_share: :lead_share_participants } }).sum do |receipt|
        receipt.amount * share_of(receipt.payment.lead, people)
      end
    end

    # Worked out from the preloaded Lead (Lead#share_fraction_for queries per call).
    def share_of(lead, people)
      return 1 unless people

      if lead.lead_share
        lead.lead_share.lead_share_participants.select { |participant| people.include?(participant.admin_id) }.sum { |participant| participant.percentage / 100r }
      else
        people.include?(lead.assigned_to_id) ? 1 : 0
      end
    end

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
