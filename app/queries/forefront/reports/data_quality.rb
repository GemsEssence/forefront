module Forefront
  module Reports
    # Records that need tidying, counted per check.
    class DataQuality < Base
      report key: "data_quality", title: "Data quality", group: :admin, roles: %w[admin]

      def columns
        [ column(:check, "Check", :text), column(:count, "Count", :count) ]
      end

      def rows
        scope = context.scope
        [
          [ "Leads needing a next step", Dashboard::Metrics.fetch(:needs_next_step).relation(scope).count ],
          [ "Rejected Signup API calls", Dashboard::Metrics.fetch(:failed_intake).relation(scope).count ],
          [ "Customers with no email", Customer.where(email: [ nil, "" ]).count ],
          [ "Leads with no product", scope.leads.where(product_id: nil).count ],
          [ "Won leads with no payment", scope.leads.won.where.not(id: Payment.select(:lead_id)).count ]
        ]
      end
    end
  end
end
