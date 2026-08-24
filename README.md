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
  role: "admin"
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
the Rails console (see below). There is no web UI yet for creating further Admins,
Managers, or Sales persons — for now, use the console the same way (see Admin Roles).

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

Every `Forefront::Admin` has a `role`, one of three tiers:

- **Admin**: Full access to all resources.
- **Manager**: Access to their own resources plus those of their direct reports
  (Sales persons and Managers where `manager_id` points to them).
- **Sales person**: Access only to resources they created or are assigned to.

```ruby
# Create an admin (full access)
Forefront::Admin.create!(name: "Admin", email: "admin@example.com", password: "pass", role: "admin")

# Create a manager
manager = Forefront::Admin.create!(name: "Manager", email: "manager@example.com", password: "pass", role: "manager")

# Create a sales person reporting to that manager
Forefront::Admin.create!(name: "Rep", email: "rep@example.com", password: "pass", role: "sales_person", manager: manager)
```

### Authorization

Uses Pundit policies:
- **Create**: Any admin
- **Read**: Created by, assigned to, or (for a Manager) one of their direct reports; Admin sees all
- **Update**: Same as Read
- **Delete**: Admin only

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
