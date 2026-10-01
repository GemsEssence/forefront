module Forefront
  # The Unassigned pool (CONTEXT.md): Tickets and Leads nobody is assigned to.
  # A Sales person sees the part whose Product is allocated to them and may
  # take from it; Managers and Admins see all of it and assign from it.
  # Included by TicketPolicy and LeadPolicy.
  module UnassignedPool
    def self.visible_to(admin, scope)
      pool = scope.where(assigned_to_id: nil)
      return pool if admin.admin? || admin.manager?

      pool.where(product_id: admin.product_ids)
    end

    def take?
      current_admin.sales_person? && pooled_for_me?
    end

    private

    def in_pool?
      record_in_pool.assigned_to_id.nil?
    end

    def pooled_for_me?
      in_pool? && (current_admin.admin? || current_admin.manager? || current_admin.product_ids.include?(record_in_pool.product_id))
    end

    def manages_pool?
      current_admin.manager? && in_pool?
    end
  end
end
