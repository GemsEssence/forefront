class CreateForefrontLeadShareParticipants < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_lead_share_participants do |t|
      t.references :lead_share, null: false, foreign_key: { to_table: :forefront_lead_shares }
      t.references :admin, null: false, foreign_key: { to_table: :forefront_admins }
      t.decimal :percentage, precision: 5, scale: 2, null: false

      t.timestamps
    end

    add_index :forefront_lead_share_participants, [ :lead_share_id, :admin_id ], unique: true, name: "index_forefront_lsp_on_lead_share_and_admin"
  end
end
