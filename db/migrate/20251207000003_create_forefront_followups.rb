class CreateForefrontFollowups < ActiveRecord::Migration[6.0]
  def change
    create_table :forefront_followups do |t|
      t.references :followupable, polymorphic: true, null: false, index: true

      t.references :assigned_to, null: false, foreign_key: { to_table: :forefront_admins }

      t.string :followup_type, null: false, default: 'call'
      t.datetime :scheduled_for
      t.string :status, null: false, default: 'pending'
      t.text :outcome
      t.datetime :completed_at

      t.references :created_by, null: false, foreign_key: { to_table: :forefront_admins }

      t.timestamps
    end

    add_index :forefront_followups, [:followupable_type, :followupable_id]
    add_index :forefront_followups, :assigned_to_id
  end
end
