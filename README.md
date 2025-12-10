# Forefront

A comprehensive Rails engine for ticket and lead management with built-in authentication, authorization, activities tracking, assignments, status history, and followups.

## Features

✨ **Ticket & Lead Management** - Track customer issues and sales leads
👥 **Admin Users** - Built-in or custom authentication
🔒 **Pundit Authorization** - Fine-grained access control
📝 **Activities Tracking** - Log all interactions
👤 **Assignments** - Assign tickets/leads to team members with history
📋 **Status History** - Track changes over time
📞 **Followups** - Schedule and track customer followups
🎯 **Customers** - Manage customer information

## Quick Start (Default Authentication)

### 1. Add to Gemfile

```ruby
gem 'forefront'
```

### 2. Install

```bash
bundle install
rails generate forefront:install
rails db:migrate
```

### 3. Create Your First Admin

```bash
rails console
Forefront::Admin.create!(
  name: "Your Name",
  email: "admin@example.com",
  password: "password123",
  super_admin: true
)
```

### 4. Access Forefront

Navigate to: `http://localhost:3000/forefront`

Sign in and start managing tickets and leads!

## Authentication Options

### Option 1: Use Forefront's Built-in Admin (Recommended for New Apps)

**No configuration needed!** Just install and use. The gem provides:
- `Forefront::Admin` model with Devise
- Built-in sign up/sign in
- Super admin support
- All features ready to use

👉 See [GETTING_STARTED.md](./GETTING_STARTED.md) for detailed guide

### Option 2: Use Your Own User Model (For Existing Apps)

Configure in `config/initializers/forefront.rb`:

```ruby
Forefront.setup do |config|
  config.admin_class = "User"
  config.authenticate_with = :authenticate_user!
  config.current_admin_method = :current_user
end
```

Your User model must implement:
```ruby
def super_admin?
  role == 'admin'  # or your custom logic
end
```

👉 See [AUTHENTICATION_CONFIGURATION.md](./AUTHENTICATION_CONFIGURATION.md) for detailed guide

## Installation

Add this line to your application's Gemfile:

```ruby
gem "forefront"
```

Then execute:
```bash
$ bundle
$ rails generate forefront:install
$ rails db:migrate
```

The generator will:
- Create migrations for all Forefront tables
- Copy configuration files
- Mount the engine in your routes

## Mount the Engine

The generator does this automatically, but if needed:

```ruby
# config/routes.rb
mount Forefront::Engine, at: "/forefront"
```

## Usage

Once installed, visit:
- **Dashboard**: `http://localhost:3000/forefront`
- **Sign up**: `http://localhost:3000/forefront/admins/sign_up`
- **Sign in**: `http://localhost:3000/forefront/admins/sign_in`
- **Tickets**: `http://localhost:3000/forefront/tickets`
- **Leads**: `http://localhost:3000/forefront/leads`
- **Customers**: `http://localhost:3000/forefront/customers`

## Configuration

### Default (No Setup Required)

Works out of the box with:
- `Forefront::Admin` model
- Devise authentication
- Built-in authorization with Pundit

### Custom Authentication (Optional)

In `config/initializers/forefront.rb`:

```ruby
Forefront.setup do |config|
  config.admin_class = "User"
  config.authenticate_with = :authenticate_user!
  config.current_admin_method = :current_user
end
```

See [AUTHENTICATION_CONFIGURATION.md](./AUTHENTICATION_CONFIGURATION.md) for examples.

## Key Concepts

### Admin Roles

- **Super Admin**: Full access to all resources
- **Regular Admin**: Can only access/edit their own resources

```ruby
# Create super admin (full access)
Forefront::Admin.create!(name: "Admin", email: "admin@example.com", password: "pass", super_admin: true)

# Create regular admin (limited access)
Forefront::Admin.create!(name: "User", email: "user@example.com", password: "pass", super_admin: false)
```

### Authorization

Uses Pundit policies:
- **Create**: Any admin
- **Read**: Created by or assigned to the admin (super admin sees all)
- **Update**: Created by, assigned to, or super admin
- **Delete**: Super admin only

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
