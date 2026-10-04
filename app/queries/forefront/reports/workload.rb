module Forefront
  module Reports
    # Each person's open work right now.
    class Workload < Base
      report key: "workload", title: "Workload", group: :activity, roles: TEAM_ROLES

      KEYS = %i[open_tickets active_leads followups_due_today overdue_followups].freeze

      def columns
        [ column(:person, "Person", :text), column(:tickets, "Open tickets", :count), column(:leads, "Open leads", :count),
          column(:today, "Followups due today", :count), column(:overdue, "Overdue followups", :count) ]
      end

      def rows
        context.scope.rows.map do |person|
          [ person.name ] + KEYS.map { |key| Dashboard::Metrics.fetch(key).relation(context.scope.for_member(person)).count }
        end
      end
    end
  end
end
