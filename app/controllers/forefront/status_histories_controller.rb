module Forefront
  class StatusHistoriesController < ApplicationController
    before_action :find_trackable

    def create
      authorize trackable, :update?

      result = Forefront::StatusHistoryOperations::Create.new(
        trackable: trackable,
        params: trackable_params,
        current_admin: current_admin
      ).call

      respond_to do |format|
        if result[:success]
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(status_history_dom_id(trackable), partial: 'forefront/status_histories/history', locals: { trackable: trackable }),
              turbo_stream.update('flash_messages', partial: 'forefront/status_histories/flash', locals: { message: 'Status updated.' })
            ]
          end

          format.html { redirect_to trackable, notice: 'Status updated.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(status_history_modal_dom_id(trackable), partial: 'forefront/status_histories/form', locals: { trackable: trackable, errors: result[:errors] }),
              turbo_stream.update('flash_messages', partial: 'forefront/status_histories/flash', locals: { message: result[:errors].join(', ') })
            ]
          end

          format.html { redirect_to trackable, alert: result[:errors].join(', ') }
        end
      end
    end

    private

    def find_trackable
      @trackable ||= if params[:ticket_id].present?
        Ticket.find(params[:ticket_id])
      elsif params[:lead_id].present?
        Lead.find(params[:lead_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def status_history_dom_id(trackable)
      "status_history_#{trackable.class.name.demodulize.underscore}_#{trackable.id}"
    end

    def status_history_modal_dom_id(trackable)
      "status_history_modal_#{trackable.class.name.demodulize.underscore}_#{trackable.id}"
    end

    def trackable_params
      params.require(:status_history).permit(:to_user_id, :note)
    end
  end
end
