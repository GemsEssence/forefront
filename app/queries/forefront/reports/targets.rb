module Forefront
  module Reports
    # Targets whose own period overlaps the chosen one: goal, achieved (the
    # Target rule — won amounts, shared credit), gap and percent.
    class Targets < Base
      report key: "targets", title: "Target vs achievement", group: :money

      def columns
        [ column(:person, "Person", :text), column(:product, "Product", :text), column(:period, "Target period", :text),
          column(:metric, "Metric", :text), column(:goal, "Goal", :decimal), column(:achieved, "Achieved", :decimal),
          column(:gap, "Gap", :decimal), column(:percent, "%", :percent) ]
      end

      def rows
        dates = context.period.dates
        targets = Target.includes(:admin, :product).where("starts_on <= ?", dates.end)
        targets = targets.where(admin_id: context.scope.people_ids) if context.scope.people_ids
        targets = targets.where(product_id: context.scope.product_id) if context.scope.product_id
        targets.select { |target| target.ends_on >= dates.begin }.sort_by { |target| [ target.admin.name, target.starts_on ] }.map do |target|
          achieved = target.achieved_value
          [ target.admin.name, target.product.name, "#{target.period.humanize} from #{target.starts_on.strftime("%-d %b %Y")}",
            target.metric.humanize, target.goal_value, achieved, [ target.goal_value - achieved, 0 ].max, achieved * 100 / target.goal_value ]
        end
      end
    end
  end
end
