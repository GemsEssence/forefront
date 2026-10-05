module Forefront
  module Reports
    # Contact reveals per person in the period, and how many were followed by
    # no recorded Action (ContactReveal#answered?).
    class NumberReveals < Base
      report key: "number_reveals", title: "Number reveal", group: :activity, roles: %w[admin]

      def columns
        [ column(:person, "Person", :text), column(:reveals, "Reveals", :count),
          column(:customers, "Customers", :count), column(:unanswered, "No action after", :count) ]
      end

      def rows
        reveals = ContactReveal.includes(:admin, :customer).where(created_at: context.period.times)
        reveals = reveals.where(admin_id: context.scope.people_ids) if context.scope.people_ids
        reveals.group_by(&:admin).sort_by { |admin, _| admin.name }.map do |admin, list|
          [ admin.name, list.size, list.map(&:customer_id).uniq.size, list.count { |reveal| !reveal.answered? } ]
        end
      end
    end
  end
end
