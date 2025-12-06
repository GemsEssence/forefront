class CreateForefrontLeads < ActiveRecord::Migration[7.0]
  def change
    create_table :forefront_leads do |t|
      t.string :title, null: false
      t.text :description
      t.references :customer, null: false, foreign_key: { to_table: :forefront_customers }
      t.references :created_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.references :assigned_to, null: true, foreign_key: { to_table: :forefront_admins }
      t.string :source, null: false, default: 'website'
      t.string :status, null: false, default: 'new'
      t.date :due_at
      t.datetime :next_followup_at

      t.timestamps
    end

    add_index :forefront_leads, :customer_id
    add_index :forefront_leads, :created_by_id
    add_index :forefront_leads, :assigned_to_id
    add_index :forefront_leads, :source
    add_index :forefront_leads, :status
    add_index :forefront_leads, :due_at
    add_index :forefront_leads, :next_followup_at
  end
end

