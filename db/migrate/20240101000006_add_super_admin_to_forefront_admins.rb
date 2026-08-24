class AddSuperAdminToForefrontAdmins < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_admins, :super_admin, :boolean, default: false, null: false
    add_index :forefront_admins, :super_admin
  end
end
