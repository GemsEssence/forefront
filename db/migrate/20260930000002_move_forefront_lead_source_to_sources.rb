# Leads stored their source as a hard-coded enum key ("india_soft"). Each of
# those becomes a Source row (named as the old enum labelled it), every Lead
# points at its Source, and the string column goes.
class MoveForefrontLeadSourceToSources < ActiveRecord::Migration[6.1]
  ENUM_NAMES = {
    "website" => "Website", "phone" => "Phone", "email" => "Email", "referral" => "Referral",
    "linkedin" => "Linkedin", "upwork" => "Upwork", "freelancer" => "Freelancer", "gitex" => "Gitex",
    "india_soft" => "India Soft", "event" => "Event", "other" => "Other"
  }.freeze

  class Source < ActiveRecord::Base
    self.table_name = "forefront_sources"
  end

  class Lead < ActiveRecord::Base
    self.table_name = "forefront_leads"
  end

  def up
    add_reference :forefront_leads, :source, foreign_key: { to_table: :forefront_sources }

    ENUM_NAMES.each_value { |name| Source.find_or_create_by!(name: name) }
    Lead.distinct.pluck(:source).each do |key|
      name = ENUM_NAMES.fetch(key, key.to_s.humanize.presence || "Other")
      Lead.where(source: key).update_all(source_id: Source.find_or_create_by!(name: name).id)
    end

    change_column_null :forefront_leads, :source_id, false
    remove_index :forefront_leads, :source
    remove_column :forefront_leads, :source
  end

  def down
    add_column :forefront_leads, :source, :string, null: false, default: "website"
    add_index :forefront_leads, :source

    keys = ENUM_NAMES.invert
    Source.find_each do |source|
      Lead.where(source_id: source.id).update_all(source: keys.fetch(source.name, "other"))
    end

    remove_reference :forefront_leads, :source, foreign_key: { to_table: :forefront_sources }
  end
end
