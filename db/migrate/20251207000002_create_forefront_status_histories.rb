class CreateForefrontStatusHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_status_histories do |t|
      t.references :trackable, polymorphic: true, null: false, index: true

      t.string :old_status
      t.string :new_status, null: false
      
      t.references :changed_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.text :note

      t.timestamps
    end
  end
end
