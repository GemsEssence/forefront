require "net/http"
require "json"

module Forefront
  # The daily Expiry pull (CONTEXT.md, ADR 0007): Forefront asks each
  # Product's own application for its active subscriptions and their end
  # dates, moves the matching Subscriptions' expires_at, and opens or
  # resolves Renewal Tickets from them.
  module ExpiryOperations
    # One Product's endpoint. The contract Forefront defines:
    #   GET <expiry_endpoint_url>?page=N
    #   Authorization: Bearer <expiry_endpoint_token>
    #   200 { "subscriptions": [ { "phone": "...", "expires_on": "YYYY-MM-DD" } ], "next_page": N | null }
    class Endpoint
      class Error < StandardError; end

      def initialize(product)
        @product = product
      end

      def page(number)
        uri = URI.parse(@product.expiry_endpoint_url)
        uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) + [ [ "page", number ] ])
        response = Net::HTTP.get_response(uri, { "Authorization" => "Bearer #{@product.expiry_endpoint_token}", "Accept" => "application/json" })
        raise Error, "#{@product.name}'s expiry endpoint answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        raise Error, "#{@product.name}'s expiry endpoint sent no subscriptions list" unless body.is_a?(Hash) && body["subscriptions"].is_a?(Array)

        body
      rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, URI::InvalidURIError => e
        raise Error, "#{@product.name}'s expiry endpoint failed: #{e.message}"
      end
    end

    class Pull
      attr_reader :product, :endpoint, :today, :counts

      def initialize(product:, endpoint: Endpoint.new(product), today: Date.current, settings: Settings.current)
        @product = product
        @endpoint = endpoint
        @today = today
        @settings = settings
        @counts = { updated: 0, opened: 0, resolved: 0, skipped: 0 }
      end

      def call
        each_row { |row| handle(row) }
        { success: true, **counts }
      end

      private

      def each_row
        number = 1
        while number
          body = endpoint.page(number)
          body["subscriptions"].each { |row| yield row }
          number = body["next_page"].presence&.to_i
        end
      end

      # A row that matches no Customer, or a Customer with no Subscription
      # for the Product, is skipped: Forefront never invents either.
      def handle(row)
        country_code = row["country_code"].presence || @settings.default_country_code
        customer = Customer.find_by(country_code: country_code, phone: Customer.national_number(row["phone"], country_code: country_code))
        subscription = customer && Subscription.where(customer: customer, product: product).order(created_at: :desc).first
        expires_on = parse_date(row["expires_on"])
        return counts[:skipped] += 1 if subscription.nil? || expires_on.nil?

        if subscription.expires_at != expires_on
          subscription.update!(expires_at: expires_on)
          counts[:updated] += 1
        end

        if expires_on <= today + window
          open_renewal(subscription, expires_on)
        else
          resolve_renewal(subscription, expires_on)
        end
      end

      def window
        @settings.renewal_window_days.days
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      # One Renewal per cycle: none is opened while one from this cycle, open
      # or already answered, exists.
      def open_renewal(subscription, expires_on)
        customer = subscription.customer
        cycle_start = (expires_on - window).beginning_of_day
        return if Ticket.renewal.where(customer: customer, product: product).where(created_at: cycle_start..).exists?

        assignee = subscription.lead.assigned_to
        params = ActionController::Parameters.new(
          title: "Renew #{customer.name}'s #{product.name}",
          description: "#{customer.name}'s #{product.name} subscription expires on #{expires_on.strftime("%-d %b %Y")}. Ask them to renew.",
          category: "renewal", priority: "medium", status: "open", customer_id: customer.id, product_id: product.id,
          assigned_to_id: (assignee.id if assignee && !assignee.admin?), due_at: expires_on
        )
        result = TicketOperations::Create.new(params: params, current_admin: system).call
        raise ActiveRecord::RecordInvalid, result[:ticket] unless result[:success]

        counts[:opened] += 1
      end

      # The app is the source of truth: an expiry that moved beyond the
      # window means the Customer renewed, so the open Renewal is done.
      def resolve_renewal(subscription, expires_on)
        ticket = Ticket.renewal.unfinished.find_by(customer: subscription.customer, product: product)
        return unless ticket

        ticket.update!(renewal_outcome: "renewed")
        note = "Renewed in the app; the subscription now runs to #{expires_on.strftime("%-d %b %Y")}."
        result = StatusHistoryOperations::Create.new(trackable: ticket, params: { status: "resolved", note: note }, current_admin: system).call
        raise ActiveRecord::RecordInvalid, ticket unless result[:success]

        counts[:resolved] += 1
      end

      def system
        @system ||= Admin.system_actor
      end
    end
  end
end
