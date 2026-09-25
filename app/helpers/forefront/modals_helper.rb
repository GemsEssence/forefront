module Forefront
  module ModalsHelper
    # DOM id of a record's modal, e.g. modal_id(:assignment, ticket) =>
    # "assignment_modal_ticket_12". Controllers use it to re-render a modal
    # (open, with errors) in place when its form fails validation.
    def modal_id(kind, record)
      "#{kind}_modal_#{record.class.name.demodulize.underscore}_#{record.id}"
    end
  end
end
