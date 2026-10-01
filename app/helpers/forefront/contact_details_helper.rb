module Forefront
  # A Customer's contact details as the signed-in Staff member may see them:
  # in full for Admins, masked for everyone else (CustomerPolicy).
  module ContactDetailsHelper
    def shown_email(customer)
      policy(customer).see_contact_details? ? customer.email : customer.masked_email
    end

    def shown_phone(customer)
      policy(customer).see_contact_details? ? customer.full_phone : customer.masked_phone
    end
  end
end
