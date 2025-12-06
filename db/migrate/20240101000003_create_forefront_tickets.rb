class CreateForefrontTickets < ActiveRecord::Migration[7.0]
  def change
    create_table :forefront_tickets do |t|
      t.string :title, null: false
      t.text :description
      t.references :customer, null: false, foreign_key: { to_table: :forefront_customers }
      t.references :created_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.references :assigned_to, null: true, foreign_key: { to_table: :forefront_admins }
      t.string :category, null: false, default: 'issue'
      t.string :priority, null: false, default: 'medium'
      t.string :status, null: false, default: 'new'
      t.date :due_at
      t.datetime :next_followup_at

      t.timestamps
    end

    add_index :forefront_tickets, :customer_id
    add_index :forefront_tickets, :created_by_id
    add_index :forefront_tickets, :assigned_to_id
    add_index :forefront_tickets, :category
    add_index :forefront_tickets, :priority
    add_index :forefront_tickets, :status
    add_index :forefront_tickets, :due_at
    add_index :forefront_tickets, :next_followup_at
  end
end

