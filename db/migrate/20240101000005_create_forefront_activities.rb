class CreateForefrontActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :forefront_activities do |t|
      t.references :actable, polymorphic: true, null: false, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.string :activity_type, null: false, default: 'comment'
      t.text :body, null: false

      t.timestamps
    end

    add_index :forefront_activities, :activity_type
    add_index :forefront_activities, :created_at
  end
end

