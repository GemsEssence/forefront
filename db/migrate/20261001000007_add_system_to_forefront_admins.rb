# The one non-human Staff record, "System", that acts for automated inputs
# such as a Signup. It never signs in and is never given work.
class AddSystemToForefrontAdmins < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_admins, :system, :boolean, null: false, default: false
  end
end
