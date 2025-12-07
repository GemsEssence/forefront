Forefront.setup do |config|
  # The class name of your admin model (using Devise)
  # Default is "Forefront::Admin" - only change if you're using a custom admin class
  config.admin_class          = "Forefront::Admin"

  # Method used to authenticate admins (Devise method)
  # Default is :authenticate_admin! - only change if you're using a custom authentication method
  config.authenticate_with    = :authenticate_admin!

  # Method that returns the currently logged in admin (Devise method)
  # Default is :current_admin - only change if you're using a custom method
  config.current_admin_method = :current_admin
end
