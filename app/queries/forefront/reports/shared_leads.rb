module Forefront
  module Reports
    # Shared Leads involving the people in view: the agreed split, money
    # received in the period, and what that credits each participant in view.
    class SharedLeads < Base
      include ActionView::Helpers::NumberHelper
      include CurrencyHelper

      report key: "shared_leads", title: "Shared lead", group: :money

      def columns
        [ column(:lead, "Lead", :text), column(:customer, "Customer", :text), column(:split, "Split", :text),
          column(:received, "Received", :money), column(:credited, "Credited", :text) ]
      end

      def rows
        people = context.scope.people_ids
        shares = shares_in_view(people).to_a
        received = received_by_lead(shares.map(&:lead_id))
        shares.sort_by { |share| share.lead.title }.map do |share|
          amount = received.fetch(share.lead_id, 0)
          participants = share.lead_share_participants.sort_by { |participant| -participant.percentage }
          in_view = participants.select { |participant| people.nil? || people.include?(participant.admin_id) }
          [ share.lead.title, share.lead.customer.name,
            participants.map { |participant| "#{participant.admin.name} #{participant.percentage.to_i}%" }.join(" · "),
            amount,
            in_view.map { |participant| "#{participant.admin.name} #{format_money(amount * participant.percentage / 100)}" }.join(" · ") ]
        end
      end

      private

      def shares_in_view(people)
        shares = LeadShare.includes(lead: :customer, lead_share_participants: :admin)
        shares = shares.where(id: LeadShareParticipant.where(admin_id: people).select(:lead_share_id)) if people
        shares = shares.where(lead_id: Lead.where(product_id: context.scope.product_id).select(:id)) if context.scope.product_id
        shares
      end

      # Money received in the period per Lead id, in one query.
      def received_by_lead(lead_ids)
        Receipt.joins(:payment).where(received_on: context.period.dates, Payment.table_name => { lead_id: lead_ids })
               .group("#{Payment.table_name}.lead_id").sum(:amount)
      end
    end
  end
end
