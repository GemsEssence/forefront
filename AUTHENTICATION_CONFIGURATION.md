# Forefront Authentication Configuration Guide

Forefront supports **two authentication modes**:

## Mode 1: Default (Forefront::Admin with Devise)

If you want to use Forefront's built-in `Forefront::Admin` model with Devise, **no configuration is needed**. The gem works out of the box.

```ruby
# No setup required - this is the default
```

## Mode 2: Custom Host App Authentication

If you want to use your own user model and authentication system (e.g., your app's `User` model with Devise, Warden, or custom auth), add this to `config/initializers/forefront.rb`:

```ruby
Forefront.setup do |config|
  # Your user model class name (as string)
  config.admin_class = "User"
  
  # Your authentication method (Devise usually provides this)
  config.authenticate_with = :authenticate_user!
  
  # Your current user method
  config.current_admin_method = :current_user
end
```

### Requirements for Custom Authentication

Your user model **MUST** implement a `super_admin?` method:

```ruby
class User < ApplicationRecord
  def super_admin?
    role == 'admin' # or your custom logic
    # Examples:
    # is_admin == true
    # permissions.include?('admin')
  end
end
```

## Examples

### Using Devise with Custom User Model

In your host app's `config/initializers/forefront.rb`:

```ruby
Forefront.setup do |config|
  config.admin_class = "User"
  config.authenticate_with = :authenticate_user!
  config.current_admin_method = :current_user
end
```

Your `User` model:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  
  enum role: { user: 0, admin: 1, super_admin: 2 }
  
  def super_admin?
    role == 'super_admin'
  end
end
```

### Using Custom Authentication

In `config/initializers/forefront.rb`:

```ruby
Forefront.setup do |config|
  config.admin_class = "Employee"
  config.authenticate_with = :require_login
  config.current_admin_method = :logged_in_employee
end
```

Your controller:

```ruby
class ApplicationController < ActionController::Base
  def require_login
    redirect_to login_path unless logged_in_employee.present?
  end
  
  def logged_in_employee
    @logged_in_employee ||= Employee.find(session[:employee_id])
  end
end
```

## Policy Scopes

All Pundit policies in Forefront respect the `super_admin?` method on your user model:

- **Super Admin**: Full access to all resources
- **Regular Admin**: Limited access (can only view/edit their own resources)

## Migration Notes

If you're migrating from Forefront::Admin to a custom user model:

1. Your database should have foreign keys pointing to your custom user table instead of `forefront_admins`
2. Update any migrations in Forefront that reference `forefront_admins`
3. Implement the configuration in `config/initializers/forefront.rb`
4. Ensure your user model has the `super_admin?` method

## Troubleshooting

**Error: "undefined method `authenticate_user!`"**
- Make sure your custom authentication method is defined in the host app's ApplicationController
- Verify the method name matches `config.authenticate_with`

**Error: "undefined method `super_admin?`"**
- Add the `super_admin?` method to your user model
- Check that it returns true/false properly

**Authorization failing for admins**
- Verify that `current_admin_method` returns the correct user instance
- Check Pundit policies to ensure they call `super_admin?` correctly
