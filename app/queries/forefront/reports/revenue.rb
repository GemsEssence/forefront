module Forefront
  module Reports
    # Money received in the period per Product, split one-off vs instalment
    # (counted in full; shared splits are in the Shared lead report). The
    # period's Receipts are plucked once and filtered in Ruby, so the queries
    # don't grow with the Products or the buckets.
    class Revenue < MetricReport
      report key: "revenue", title: "Revenue", group: :money, roles: TEAM_ROLES, filters: %i[source campaign], breakdown: true

      def label_columns
        [ column(:product, "Product", :text) ]
      end

      def row_keys
        products = context.scope.product_id ? Product.where(id: context.scope.product_id) : Product.order(:name)
        products.map { |product| [ [ product.name ], product.id ] } + (context.scope.product_id ? [] : [ [ [ "No product" ], nil ] ])
      end

      def metrics
        @metrics ||= [
          Metric.new(key: :one_off, title: "One-off", format: :money, periodic: true,
                     value: ->(id, ctx) { total(receipts(id, ctx).reject { |row| row[1] }) }),
          Metric.new(key: :instalment, title: "Instalments", format: :money, periodic: true,
                     value: ->(id, ctx) { total(receipts(id, ctx).select { |row| row[1] }) }),
          Metric.new(key: :total, title: "Total", format: :money, periodic: true, value: ->(id, ctx) { total(receipts(id, ctx)) })
        ]
      end

      private

      # Rows are [product_id, installment_id, amount, received_on] for every
      # Receipt in the period on an in-scope Lead.
      def receipt_rows
        @receipt_rows ||= Receipt.where(received_on: context.period.dates, payment_id: Payment.where(lead_id: context.leads.select(:id)).select(:id))
                                 .joins(payment: :lead)
                                 .pluck(Lead.arel_table[:product_id], :installment_id, :amount, :received_on)
      end

      def receipts(product_id, ctx)
        dates = ctx.period.dates
        receipt_rows.select { |row| row[0] == product_id && dates.cover?(row[3]) }
      end

      def total(rows)
        rows.sum(BigDecimal("0")) { |row| row[2] }
      end
    end
  end
end
