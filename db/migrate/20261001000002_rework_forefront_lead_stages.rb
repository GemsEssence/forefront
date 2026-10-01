# Lead stages become Open, Contacted, Demo, Proposal, Negotiation, Won, Lost.
# "Follow Up" was waiting on the Customer rather than a stage, so those Leads
# go back to Contacted. "NDA Signed" was a white-label agreement, so those
# Leads become white-label, at Negotiation, with the agreement signed on the
# day they were last updated.
class ReworkForefrontLeadStages < ActiveRecord::Migration[6.1]
  class Lead < ActiveRecord::Base
    self.table_name = "forefront_leads"
  end

  def up
    Lead.where(status: "Follow Up").update_all(status: "Contacted")
    Lead.where(status: "NDA Signed").find_each do |lead|
      lead.update_columns(status: "Negotiation", white_label: true,
                          agreement_signed_on: lead.agreement_signed_on || lead.updated_at.to_date)
    end
  end

  def down
    # Contacted and Negotiation were stages before too; nothing to undo.
  end
end
