module Forefront
  # Unattached Receipts (CONTEXT.md): Admins and Managers see them all, a
  # Sales person those for Products allocated to them. Attaching is decided
  # by the Lead being paid (LeadPolicy#update?); discarding takes a Manager
  # or Admin.
  class ReceiptPolicy < ApplicationPolicy
    def index?
      true
    end

    def discard?
      current_admin.admin? || current_admin.manager?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope if current_admin.admin? || current_admin.manager?

        scope.where(product_id: current_admin.product_ids)
      end
    end
  end
end
