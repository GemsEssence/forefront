module Forefront
  # The daily Expiry pull for every Product that names an endpoint. Schedule
  # it in the host app once a day, or run `bin/rails forefront:pull_expiries`
  # from cron. One Product's failing endpoint is logged and the rest go on.
  class ExpiryPullJob < ApplicationJob
    queue_as :default

    def perform
      Product.where.not(expiry_endpoint_url: [ nil, "" ]).find_each do |product|
        result = ExpiryOperations::Pull.new(product: product).call
        Rails.logger.info("Forefront expiry pull for #{product.name}: #{result.except(:success).map { |k, v| "#{v} #{k}" }.join(", ")}")
      rescue ExpiryOperations::Endpoint::Error, ActiveRecord::RecordInvalid => e
        Rails.logger.error("Forefront expiry pull for #{product.name} failed: #{e.message}")
      end
    end
  end
end
