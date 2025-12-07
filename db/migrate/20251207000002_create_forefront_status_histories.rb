class CreateForesightStatusHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :forefront_status_histories do |t|
      t.references :trackable, polymorphic: true, null: false, index: true

      t.string :old_status
      t.string :new_status, null: false
      
      t.references :changed_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.text :note

      t.timestamps
    end

    add_index :forefront_status_histories, [:trackable_type, :trackable_id]
    add_index :forefront_status_histories, :changed_by_id
    add_foreign_key :forefront_status_histories, :forefront_admins, column: :changed_by_id
  end
end
