module Forefront
  module Reports
    # Instalments due in the period, per Lead: what was scheduled, paid on
    # time or late, what's overdue, and what the Lead still owes.
    class Instalments < Base
      report key: "instalments", title: "Instalment", group: :money

      def columns
        [ column(:lead, "Lead", :text), column(:customer, "Customer", :text), column(:person, "Person", :text),
          column(:scheduled, "Scheduled", :money), column(:on_time, "Paid on time", :count), column(:late, "Paid late", :count),
          column(:overdue, "Overdue", :count), column(:balance, "Balance outstanding", :money) ]
      end

      def rows
        due = context.scope.installments.where(due_on: context.period.dates)
                     .includes(payment: [ { lead: %i[customer assigned_to] }, { installments: :receipts } ])
        due.group_by { |installment| installment.payment.lead }.sort_by { |lead, _| lead.title }.map do |lead, list|
          paid = list.select(&:paid_at)
          [ lead.title, lead.customer.name, lead.assigned_to&.name, list.sum(&:amount),
            paid.count { |inst| inst.paid_at.to_date <= inst.due_on }, paid.count { |inst| inst.paid_at.to_date > inst.due_on },
            list.count { |inst| inst.paid_at.nil? && inst.due_on < Date.current }, outstanding(list.first.payment) ]
        end
      end

      private

      # What's left on the Lead's unpaid Instalments, from preloaded receipts.
      def outstanding(payment)
        payment.installments.reject(&:paid?).sum { |inst| inst.amount - inst.receipts.sum(&:amount) }
      end
    end
  end
end
