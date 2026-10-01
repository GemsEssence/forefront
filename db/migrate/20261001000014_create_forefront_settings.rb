# Settings Admins change in Forefront itself (alert time limits, which
# alerts are emailed, the default country code). Defaults live in code, so
# a row exists only once an Admin has saved the settings page.
class CreateForefrontSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end
    add_index :forefront_settings, :key, unique: true
  end
end
