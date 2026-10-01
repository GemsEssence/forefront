# Why a Lead was lost: a list Admins maintain, seeded with common reasons.
class CreateForefrontLostReasons < ActiveRecord::Migration[6.1]
  DEFAULTS = [ "Price", "Went with a competitor", "No response", "Not a fit", "Other" ].freeze

  class LostReason < ActiveRecord::Base
    self.table_name = "forefront_lost_reasons"
  end

  def up
    create_table :forefront_lost_reasons do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :forefront_lost_reasons, :name, unique: true

    DEFAULTS.each { |name| LostReason.create!(name: name) }
  end

  def down
    drop_table :forefront_lost_reasons
  end
end
