require "csv"

module Forefront
  class LeadCsvExport
    HEADERS = [
      "Title", "Customer", "Product", "Status", "Source",
      "Assigned To", "Created By", "Created At", "Won At", "Expires At"
    ].freeze

    def initialize(leads)
      @leads = leads
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << HEADERS

        @leads.includes(:customer, :product, :assigned_to, :created_by).each do |lead|
          csv << [
            lead.title,
            lead.customer.name,
            lead.product&.name,
            lead.status,
            lead.source,
            lead.assigned_to&.name,
            lead.created_by.name,
            lead.created_at,
            lead.won_at,
            lead.expires_at
          ]
        end
      end
    end
  end
end
