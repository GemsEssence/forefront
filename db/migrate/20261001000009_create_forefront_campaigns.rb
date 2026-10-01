# A marketing push Staff run on a Source (an ad run on LinkedIn, a stand
# at Gitex), so enquiries it brings in can be credited to it (ADR 0005).
class CreateForefrontCampaigns < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_campaigns do |t|
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.references :source, null: false, foreign_key: { to_table: :forefront_sources }
      t.references :created_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.timestamps
    end
  end
end
