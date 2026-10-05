module Forefront
  module Reports
    # Subscriptions on Leads in view, per Product, by how soon they expire.
    class Subscriptions < Base
      report key: "subscriptions", title: "Subscription", group: :money

      BANDS = [ [ "Active (61+ days)", 61..nil ], [ "0–7 days", 0..7 ], [ "8–30 days", 8..30 ], [ "31–60 days", 31..60 ], [ "Expired", nil..-1 ] ].freeze

      def columns
        [ column(:product, "Product", :text) ] + BANDS.map { |label, _| column(label.parameterize(separator: "_").to_sym, label, :count) }
      end

      def rows
        today = Date.current
        subscriptions = context.scope.subscriptions.includes(:product)
        subscriptions.group_by(&:product).sort_by { |product, _| product.name }.map do |product, list|
          days = list.map { |subscription| (subscription.expires_at - today).to_i }
          [ product.name ] + BANDS.map { |_, band| days.count { |day| band.cover?(day) } }
        end
      end
    end
  end
end
