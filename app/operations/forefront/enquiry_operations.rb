module Forefront
  # A Customer getting in touch after seeing a Campaign (CONTEXT.md). The
  # enquiry is a Ticket for the Product they asked about, credited to the
  # Campaign (ADR 0005); one they already have open is reused, keeping the
  # Campaign that brought them first.
  module EnquiryOperations
    class Record
      attr_reader :campaign, :params, :current_admin, :errors, :ticket

      def initialize(campaign:, params:, current_admin:)
        @campaign = campaign
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @errors = missing_fields
        return { success: false, errors: errors } if errors.any?

        Ticket.transaction do
          found = CustomerOperations::FindOrCreateByPhone.new(params: params, current_admin: current_admin).call
          @errors = found[:errors]
          @notes = found[:notes]
          if errors.empty?
            existing = found[:customer].tickets.unfinished.find_by(product_id: product.id)
            existing ? add_to(existing) : open_ticket(found[:customer])
          end
          raise ActiveRecord::Rollback if errors.any?
        end

        errors.any? ? { success: false, errors: errors } : { success: true, ticket: ticket }
      end

      private

      def product
        @product ||= Product.find_by(id: params[:product_id])
      end

      def missing_fields
        missing = %i[name phone].filter_map { |field| "#{field.to_s.humanize} can't be blank" if params[field].blank? }
        missing << "Product must be chosen" unless product
        missing
      end

      def add_to(existing)
        @ticket = existing
        existing.update!(campaign: campaign) if existing.campaign.nil?
        body = [ "Also came via #{campaign.name}.", params[:note].presence ].compact.join(" ")
        result = ActivityOperations::Create.new(params: ActionController::Parameters.new(activity_type: "comment", body: body),
                                                actable: existing, current_admin: current_admin).call
        @errors = result[:errors] unless result[:success]
      end

      def open_ticket(customer)
        description = [ params[:note].presence || "Enquired about #{product.name} after #{campaign.name}.", *@notes ].join("\n\n")
        attributes = {
          title: "Enquiry: #{customer.name} about #{product.name}", description: description,
          category: "enquiry", priority: "medium", status: "open",
          customer_id: customer.id, product_id: product.id, campaign_id: campaign.id
        }
        result = TicketOperations::Create.new(params: ActionController::Parameters.new(attributes), current_admin: current_admin).call
        @ticket = result[:ticket]
        @errors = result[:errors] unless result[:success]
      end
    end
  end
end
