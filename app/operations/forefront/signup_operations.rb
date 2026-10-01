module Forefront
  # A Customer signing up in one of the Products' own applications
  # (CONTEXT.md: Signup). System finds the Customer by country code and
  # phone, or creates them, and opens an unassigned Ticket asking for a call.
  module SignupOperations
    class Receive
      attr_reader :product, :params, :errors

      def initialize(product:, params:)
        @product = product
        @params = params
        @errors = []
        @notes = []
      end

      def call
        @errors = missing_fields
        return rejected if errors.any?

        status = nil
        Customer.transaction do
          customer = find_or_create_customer
          status = customer && (repeat_signup(customer) || open_ticket(customer))
          raise ActiveRecord::Rollback if errors.any?
        end

        errors.any? ? rejected : { success: true, status: status }
      end

      private

      def system
        @system ||= Admin.system_actor
      end

      def missing_fields
        %i[name phone].filter_map { |field| "#{field.to_s.humanize} can't be blank" if params[field].blank? }
      end

      def find_or_create_customer
        result = CustomerOperations::FindOrCreateByPhone.new(params: params, current_admin: system).call
        @errors = result[:errors]
        @notes = result[:notes]
        result[:customer]
      end

      def repeat_signup(customer)
        ticket = customer.tickets.signup.unfinished.find_by(product: product)
        return unless ticket

        body = "Signed up again for #{product.name} on #{Date.current.strftime("%-d %b %Y")}."
        ActivityOperations::Create.new(params: ActionController::Parameters.new(activity_type: "comment", body: body),
                                       actable: ticket, current_admin: system).call
        :ok
      end

      def open_ticket(customer)
        result = TicketOperations::Create.new(params: ActionController::Parameters.new(ticket_attributes(customer)), current_admin: system).call
        @errors = result[:errors] unless result[:success]
        :created
      end

      def ticket_attributes(customer)
        {
          title: "Schedule a call: #{customer.name} signed up for #{product.name}",
          description: ([ "#{customer.name} signed up in #{product.name}'s application. Call them to schedule a conversation." ] +
                        (params[:external_id].present? ? [ "Their user id there: #{params[:external_id]}." ] : []) + @notes).join("\n\n"),
          category: "signup", priority: "high", status: "open",
          customer_id: customer.id, product_id: product.id
        }
      end

      # Recorded so Admins can see what the product platforms are sending
      # that doesn't get in; the errors name fields, never contact details.
      def rejected
        AuditEvent.record!(actor: system, action: "rejected_signup", auditable: product,
                           audited_changes: { "errors" => [ nil, errors.join("; ") ] })
        { success: false, errors: errors }
      end
    end
  end
end
