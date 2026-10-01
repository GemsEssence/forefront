module Forefront
  # A Staff member deliberately revealing a Customer's contact details
  # (CONTEXT.md). Shown for a minute; an Action against the Customer is
  # expected afterwards.
  class ContactReveal < ApplicationRecord
    SHOWN_FOR = 1.minute

    belongs_to :admin, class_name: "Forefront::Admin"
    belongs_to :customer, class_name: "Forefront::Customer"
  end
end
