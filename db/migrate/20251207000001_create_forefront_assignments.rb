class CreateForefrontAssignments < ActiveRecord::Migration[7.0]
  def change
    create_table :forefront_assignments do |t|
      t.references :assignable, polymorphic: true, null: false, index: true
      
      t.references :from_user, null: false, foreign_key: { to_table: :forefront_admins }
      t.references :to_user, null: false, foreign_key: { to_table: :forefront_admins }

      t.references :changed_by, null: false, foreign_key: { to_table: :forefront_admins }

      t.text :note

      t.timestamps
    end

    add_index :forefront_assignments, [:assignable_type, :assignable_id]
    add_index :forefront_assignments, :from_user_id
    add_index :forefront_assignments, :to_user_id
    add_index :forefront_assignments, :changed_by_id
  end
end
