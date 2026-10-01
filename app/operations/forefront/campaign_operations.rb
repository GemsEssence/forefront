module Forefront
  module CampaignOperations
    class Create
      attr_reader :params, :current_admin, :campaign, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @campaign = Campaign.new(params.slice(:name, :starts_on, :ends_on, :source_id))
        @campaign.created_by = current_admin

        if @campaign.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @campaign)
          { success: true, campaign: @campaign }
        else
          @errors = @campaign.errors.full_messages
          { success: false, campaign: @campaign, errors: @errors }
        end
      end
    end

    class Update
      attr_reader :campaign, :params, :current_admin, :errors

      def initialize(campaign:, params:, current_admin:)
        @campaign = campaign
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if campaign.update(params.slice(:name, :starts_on, :ends_on, :source_id))
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: campaign) if campaign.saved_changes?
          { success: true, campaign: campaign }
        else
          @errors = campaign.errors.full_messages
          { success: false, campaign: campaign, errors: @errors }
        end
      end
    end
  end
end
