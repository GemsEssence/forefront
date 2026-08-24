class RemoveSuperAdminFromForefrontAdmins < ActiveRecord::Migration[6.1]
  def change
    remove_index :forefront_admins, :super_admin
    remove_column :forefront_admins, :super_admin, :boolean, default: false, null: false
  end
end
