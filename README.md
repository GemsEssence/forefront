# Forefront

A comprehensive Rails engine for ticket and lead management with built-in authentication, authorization, activities tracking, assignments, status history, and followups.

## Features

✨ **Ticket & Lead Management** - Track customer issues and sales leads
👥 **Admin Users** - Built-in Devise authentication, invite-only sign-up
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

## Authentication

Forefront ships its own `Forefront::Admin` model (Devise-backed). There is currently no
way to swap in a host app's own user model — that pluggable-auth seam is planned as a
future release once the engine's own role model (Admin/Manager/Sales person) is built out.

Sign-up is invite-only: there is no public registration form. Create the first admin via
the Rails console (see below); an already-signed-in admin can also create further admins.

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
- **Sign in**: `http://localhost:3000/forefront/admins/sign_in`
- **Tickets**: `http://localhost:3000/forefront/tickets`
- **Leads**: `http://localhost:3000/forefront/leads`
- **Customers**: `http://localhost:3000/forefront/customers`

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
