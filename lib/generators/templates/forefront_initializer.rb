Forefront.setup do |config|
  # The class name of your user model
  config.user_class          = "User"

  # Method used to authenticate users in your app (e.g., Devise)
  config.authenticate_with   = :authenticate_user!

  # Method that returns the currently logged in user
  config.current_user_method = :current_user
end
