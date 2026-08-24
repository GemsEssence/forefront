class CreateForefrontAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_assignments do |t|
      t.references :assignable, polymorphic: true, null: false, index: true
      
      t.references :from_user, null: true, foreign_key: { to_table: :forefront_admins }
      t.references :to_user, null: false, foreign_key: { to_table: :forefront_admins }

      t.references :changed_by, null: false, foreign_key: { to_table: :forefront_admins }

      t.text :note

      t.timestamps
    end
  end
end
