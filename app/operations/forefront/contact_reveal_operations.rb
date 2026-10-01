module Forefront
  module ContactRevealOperations
    class Create
      attr_reader :customer, :current_admin

      def initialize(customer:, current_admin:)
        @customer = customer
        @current_admin = current_admin
      end

      def call
        reveal = ContactReveal.create!(customer: customer, admin: current_admin)
        AuditEvent.record!(actor: current_admin, action: "revealed_contact", auditable: customer, audited_changes: {})
        { success: true, contact_reveal: reveal }
      end
    end
  end
end
