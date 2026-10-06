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
            # Sharing a Private Lead ends its privacy (CONTEXT.md).
            lead.update!(private: false) if lead.private?
            AuditEvent.record!(actor: current_admin, action: "recorded_lead_share", auditable: lead,
                               audited_changes: { "shares" => [ nil, shares_summary ] })
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

      def shares_summary
        @lead_share.lead_share_participants.map { |participant| "#{participant.admin.name} #{format("%g", participant.percentage)}%" }.join(", ")
      end

      def percentages
        params[:percentages] || {}
      end
    end
  end
end
