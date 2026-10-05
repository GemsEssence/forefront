# The Demo stage ticket is now a "New App Demo" (a Support Demo is for a
# Customer who already has the Product), and the renewal Ticket is called
# "Renewal": a plan being expired is derived from the Subscription, not a
# category. Plain UPDATEs so the migration runs on any host database.
class RenameTicketCategories < ActiveRecord::Migration[6.1]
  RENAMES = { "Demo" => "New App Demo", "Plan Expired" => "Renewal" }.freeze

  def up
    RENAMES.each { |from, to| rename_category(from, to) }
  end

  def down
    RENAMES.each { |from, to| rename_category(to, from) }
  end

  private

  def rename_category(from, to)
    execute <<~SQL.squish
      UPDATE forefront_tickets SET category = #{quote(to)} WHERE category = #{quote(from)}
    SQL
  end
end
