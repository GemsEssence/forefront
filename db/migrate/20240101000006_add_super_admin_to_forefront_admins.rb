class AddSuperAdminToForefrountAdmins < ActiveRecord::Migration[7.0]
  def change
    add_column :forefront_admins, :super_admin, :boolean, default: false, null: false
    add_index :forefront_admins, :super_admin
  end
end
