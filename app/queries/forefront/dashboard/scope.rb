# app/queries/forefront/dashboard/scope.rb
module Forefront
  module Dashboard
    # What a dashboard covers: the viewer, the period, and the Product /
    # Manager / member filters. Filters only ever narrow what the viewer may
    # see (CONTEXT.md roles): one they can't use is ignored.
    class Scope
      attr_reader :viewer, :period, :product_id, :manager_id, :member_id

      def self.from_params(viewer, params, own: false)
        new(viewer, period: Period.from_params(params), product_id: params[:product_id].presence,
                    manager_id: params[:manager_id].presence, member_id: params[:member_id].presence, own: own)
      end

      def initialize(viewer, period:, product_id: nil, manager_id: nil, member_id: nil, own: false)
        @viewer = viewer
        @period = period
        @own = own && viewer.manager?
        @product_id = product_id.to_i if product_id.present? && products.exists?(id: product_id)
        @manager_id = manager_id.to_i if manager_id.present? && viewer.admin? && Admin.people.manager.exists?(id: manager_id)
        @member_id = member_id.to_i if member_id.present? && members.exists?(id: member_id)
      end

      def own?
        @own
      end

      # The ids of the people in view, or nil for the whole company (an Admin
      # with no Manager or member picked), so unassigned work still counts.
      def people_ids
        return [ member_id ] if member_id
        return nil if viewer.admin? && manager_id.nil?

        members.ids
      end

      # Who this dashboard can be narrowed to.
      def members
        if own? || viewer.sales_person?
          Admin.where(id: viewer.id)
        elsif viewer.manager?
          Admin.where(id: [ viewer.id, *viewer.direct_report_ids ])
        elsif manager_id
          Admin.people.where(id: manager_id).or(Admin.people.where(manager_id: manager_id))
        else
          Admin.people.where.not(role: "admin")
        end
      end

      # One row per person in per-person tables.
      def rows
        member_id ? Admin.where(id: member_id) : members.order(:name)
      end

      def products
        viewer.admin? ? Product.all : viewer.products
      end

      def with(**changes)
        self.class.new(viewer, period: changes.fetch(:period, period), product_id: changes.fetch(:product_id, product_id),
                               manager_id: changes.fetch(:manager_id, manager_id), member_id: changes.fetch(:member_id, member_id), own: own?)
      end

      def previous
        with(period: period.previous)
      end

      def for_member(admin)
        with(member_id: admin.id)
      end

      def to_params
        period.to_params.merge(product_id: product_id, manager_id: manager_id, member_id: member_id,
                               tab: (own? ? "my_day" : nil)).compact
      end

      def description
        parts = [ period.label ]
        parts << Product.find(product_id).name if product_id
        parts << "#{Admin.find(manager_id).name}'s team" if manager_id && member_id.nil?
        parts << Admin.find(member_id).name if member_id
        parts.join(" · ")
      end

      def leads
        narrow(Lead.all)
      end

      def tickets
        narrow(Ticket.all)
      end

      # Followups on Leads or Tickets (or Installment reminders) for the people in view.
      def followups
        relation = Followup.all
        relation = relation.where(assigned_to_id: people_ids) if people_ids
        return relation unless product_id

        relation.where(followupable_type: Lead.name, followupable_id: Lead.where(product_id: product_id).select(:id))
                .or(relation.where(followupable_type: Ticket.name, followupable_id: Ticket.where(product_id: product_id).select(:id)))
      end

      # Work handed to the people in view (including work they took themselves).
      def assignments
        relation = Assignment.all
        relation = relation.where(to_user_id: people_ids) if people_ids
        return relation unless product_id

        relation.where(assignable_type: Lead.name, assignable_id: Lead.where(product_id: product_id).select(:id))
                .or(relation.where(assignable_type: Ticket.name, assignable_id: Ticket.where(product_id: product_id).select(:id)))
      end

      # Targets whose period includes today, for the people and Product in view.
      def current_targets
        targets = Target.includes(:admin, :product).where("starts_on <= ?", Date.current)
        targets = targets.where(admin_id: people_ids) if people_ids
        targets = targets.where(product_id: product_id) if product_id
        targets.select { |target| target.ends_on >= Date.current }
      end

      def installments
        Installment.where(payment_id: Payment.where(lead_id: leads.select(:id)).select(:id))
      end

      def receipts
        Receipt.where(payment_id: Payment.where(lead_id: leads.select(:id)).select(:id))
      end

      private

      def narrow(relation)
        relation = relation.where(assigned_to_id: people_ids) if people_ids
        product_id ? relation.where(product_id: product_id) : relation
      end
    end
  end
end
