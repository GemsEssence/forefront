class AddRoleAndManagerToForefrontAdmins < ActiveRecord::Migration[6.1]
  def up
    add_column :forefront_admins, :role, :string, null: false, default: 'sales_person'
    add_index :forefront_admins, :role
    add_reference :forefront_admins, :manager, null: true, foreign_key: { to_table: :forefront_admins }

    execute "UPDATE forefront_admins SET role = 'admin' WHERE super_admin = true"
  end

  def down
    remove_reference :forefront_admins, :manager, foreign_key: { to_table: :forefront_admins }
    remove_index :forefront_admins, :role
    remove_column :forefront_admins, :role
  end
end
