module Forefront
  module DashboardHelper
    # A metric's number (a count, or a sum over `sum`), linking to the records behind it.
    # member: shows the number for one person, as in per-person tables.
    def metric_link(key, scope, slice: nil, sum: nil, money: false, member: nil)
      scope = scope.for_member(member) if member
      value = metric_value(key, scope, slice: slice, sum: sum)
      link_to (money ? format_money(value) : number_with_delimiter(value)),
              dashboard_metric_path(key, scope.to_params.merge(slice: slice).compact),
              class: "hover:underline", data: { metric: key, slice: slice, member: member&.id, sum: sum, period: scope.period.name }.compact
    end

    # Link text other than the metric's own count (e.g. a Target's achieved value).
    def metric_link_with(text, key, scope, slice: nil)
      link_to text, dashboard_metric_path(key, scope.to_params.merge(slice: slice).compact),
              class: "hover:underline", data: { metric: key, slice: slice }.compact
    end

    def metric_value(key, scope, slice: nil, sum: nil)
      relation = Dashboard::Metrics.fetch(key).relation(scope, slice)
      sum ? relation.sum(sum) : relation.count
    end

    # ▲/▼ against the previous period.
    def metric_change(key, scope, slice: nil, sum: nil)
      now = metric_value(key, scope, slice: slice, sum: sum)
      before = metric_value(key, scope.previous, slice: slice, sum: sum)
      text, colour =
        if now == before then [ "– 0%", "text-gray-500" ]
        elsif before.zero? then [ "▲ new", "text-green-700" ]
        else
          percent = ((now - before) * 100.0 / before).round
          percent.positive? ? [ "▲ #{percent}%", "text-green-700" ] : [ "▼ #{percent.abs}%", "text-red-700" ]
        end
      content_tag :span, text, class: "ml-1 text-xs #{colour}", data: { change: key }, title: "vs #{scope.previous.period.label}"
    end

    # The record's name, linked only when the viewer may open it (a share
    # participant can see a Lead listed here without being allowed to open it).
    def subject_link(record)
      case record
      when Lead, Ticket then link_if_shown(record.title, record)
      when Installment then link_if_shown("Installment on #{record.payment.lead.title}", record.payment.lead)
      else record.to_s
      end
    end

    private

    def link_if_shown(text, record)
      policy(record).show? ? link_to(text, record, class: "text-indigo-600 hover:underline") : text
    end
  end
end
