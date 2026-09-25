module Forefront
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    # Case-insensitive pattern match for raw SQL conditions. ILIKE is
    # PostgreSQL-only; the host app may run SQLite or MySQL, where plain LIKE
    # already ignores (ASCII) case.
    def self.case_insensitive_like
      connection.adapter_name.match?(/postg/i) ? "ILIKE" : "LIKE"
    end
  end
end
