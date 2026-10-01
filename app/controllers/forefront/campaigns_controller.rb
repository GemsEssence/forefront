module Forefront
  class CampaignsController < ApplicationController
    before_action :set_campaign, only: [ :show, :edit, :update ]
    before_action :authorize_campaign, only: [ :show, :edit, :update ]

    def index
      authorize Campaign
      @campaigns = policy_scope(Campaign).includes(:source).recent
    end

    def show
    end

    def new
      @campaign = Campaign.new
      authorize @campaign
    end

    def create
      authorize Campaign
      result = CampaignOperations::Create.new(params: campaign_params, current_admin: current_admin).call

      if result[:success]
        redirect_to campaign_path(result[:campaign]), notice: "Campaign created."
      else
        @campaign = result[:campaign]
        flash.now[:alert] = result[:errors].join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CampaignOperations::Update.new(campaign: @campaign, params: campaign_params, current_admin: current_admin).call

      if result[:success]
        redirect_to campaign_path(@campaign), notice: "Campaign updated."
      else
        flash.now[:alert] = result[:errors].join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_campaign
      @campaign = Campaign.find(params[:id])
    end

    def authorize_campaign
      authorize @campaign
    end

    def campaign_params
      params.require(:campaign).permit(:name, :starts_on, :ends_on, :source_id)
    end
  end
end
