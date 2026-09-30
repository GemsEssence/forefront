# Where a Lead came from, or where a Campaign runs: a list Admins maintain
# instead of a hard-coded enum. Deactivated Sources drop out of pickers but
# stay on the records that already use them.
class CreateForefrontSources < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_sources do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :forefront_sources, :name, unique: true
  end
end
