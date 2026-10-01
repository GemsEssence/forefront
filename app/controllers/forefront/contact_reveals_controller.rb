module Forefront
  # "Show contact details": reveals a Customer's email and phone to someone
  # who can't normally see them, for a minute, and records that they did.
  class ContactRevealsController < ApplicationController
    def create
      @customer = Customer.find(params[:customer_id])
      authorize @customer, :show?
      ContactRevealOperations::Create.new(customer: @customer, current_admin: current_admin).call

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(helpers.dom_id(@customer, :contact_details),
                                                    partial: "forefront/customers/contact_details", locals: { customer: @customer, revealed: true })
        end
        format.html do
          @revealed = true
          render "forefront/customers/show"
        end
      end
    end
  end
end
