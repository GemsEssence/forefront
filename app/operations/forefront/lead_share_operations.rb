module Forefront
  module LeadShareOperations
    class Save
      attr_reader :lead, :params, :current_admin, :lead_share, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        result = nil

        Forefront::LeadShare.transaction do
          @lead_share = lead.lead_share || lead.build_lead_share
          @lead_share.recorded_by = current_admin
          @lead_share.lead_share_participants.destroy_all if @lead_share.persisted?

          percentages.each do |admin_id, percentage|
            @lead_share.lead_share_participants.build(admin_id: admin_id, percentage: percentage)
          end

          if @lead_share.save
            result = { success: true, lead_share: @lead_share }
          else
            @errors = @lead_share.errors.full_messages
            result = { success: false, lead_share: @lead_share, errors: @errors }
            raise ActiveRecord::Rollback
          end
        end

        result
      end

      private

      def percentages
        params[:percentages] || {}
      end
    end
  end
end
