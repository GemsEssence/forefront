# A lost Lead records why (a Lost reason) and a written note.
class AddLostReasonToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_leads, :lost_reason, foreign_key: { to_table: :forefront_lost_reasons }
    add_column :forefront_leads, :lost_note, :text
  end
end
