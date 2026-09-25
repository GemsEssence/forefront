module Forefront
  module CurrencyHelper
    # How each currency is usually written. Anything not listed is shown with
    # its code in front of the amount, e.g. "JPY 1,234.50".
    FORMATS = {
      # Indian grouping: 1,23,45,678.50 (lakh/crore) rather than 12,345,678.50.
      "INR" => { unit: "₹", delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/ },
      "USD" => { unit: "$" },
      "GBP" => { unit: "£" },
      "EUR" => { unit: "€", format: "%n %u", separator: ",", delimiter: "." },
      "AED" => { unit: "AED", format: "%u %n" },
      "AUD" => { unit: "A$" },
      "CAD" => { unit: "C$" },
      "SGD" => { unit: "S$" }
    }.freeze

    # An amount in the configured Forefront.currency, e.g. "₹1,50,000.00".
    def format_money(amount)
      return if amount.nil?

      number_to_currency(amount, **currency_format)
    end

    # The symbol to label amount fields with, e.g. "Amount (₹)".
    def currency_symbol
      currency_format[:unit]
    end

    private

    def currency_format
      code = Forefront.currency.to_s.upcase
      FORMATS.fetch(code) { { unit: code, format: "%u %n" } }
    end
  end
end
