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

## Plugin mode

When Forefront runs inside a host application whose own records Customers
should link to, turn on plugin mode in an initializer:

```ruby
# config/initializers/forefront.rb
Forefront.plugin_mode = true
```

This shows the "Host Application Link" (External Type / External ID) fields
on the Customer form and page. Look a linked Customer up from the host app with
`Forefront::Customer.find_by_external(external_type: "User", external_id: user.id.to_s)`.

## Currency

Amounts are shown in Indian rupees by default (`₹1,50,000.00`, with lakh/crore
grouping). To use another currency, set its ISO 4217 code in an initializer:

```ruby
# config/initializers/forefront.rb
Forefront.currency = "USD"   # $150,000.00
```

INR, USD, GBP, EUR, AED, AUD, CAD and SGD are formatted the way they're usually
written; any other code is shown in front of the amount (e.g. `JPY 1,234.50`).
This only changes how amounts are displayed — no conversion is done.

## Phone numbers

Customers are told apart by country code and phone number together. A phone
entered without a country code gets the default. Admins can change the default
on Forefront's Settings page. Until they do, it's `+91`, or whatever you set
in an initializer:

```ruby
# config/initializers/forefront.rb
Forefront.default_country_code = "+44"
```

## Alerts

Forefront alerts Staff in the app (a Notifications bell) and by email when:
- work is left unassigned
- assigned work goes stale (nobody has acted on it)
- someone reveals a customer's contact details and records nothing afterwards
- an installment is overdue

Admins set the time limits, and which alerts are emailed, on the Settings page.

New unassigned work is announced straight away. The other alerts come from a
check that your app needs to run on a schedule, for example every 15 minutes.
Either enqueue the job from whatever scheduler you use:

```ruby
Forefront::NotificationSweepJob.perform_later
```

or run the rake task from cron:

```
*/15 * * * * cd /path/to/app && bin/rails forefront:notify
```

Running it more often is safe: each alert is raised and emailed only once.
Emails go out through your app's Action Mailer settings. Set the From address
in an initializer, and make sure `config.action_mailer.default_url_options`
is set so the links in the emails work:

```ruby
# config/initializers/forefront.rb
Forefront.mailer_sender = "sales-alerts@yourcompany.com"
```

## Dashboards

Forefront's home page is a dashboard for each role:

- **Sales persons** see *My Day*: what's overdue and due today, their target
  progress, pipeline, leads shared with them, payments and renewals due, and
  their activity this period.
- **Managers** see *Team*: the unassigned pool, each person's workload and
  performance, leads by stage and source, the team target, payments and
  renewals at risk. Their own *My Day* is a tab away.
- **Admins** see *Company*: the Team view across all teams, plus revenue,
  subscriptions and data health.

Filter by period (with a comparison to the period before), product, and, for
Managers and Admins, team or person. Every number opens the list behind it.

## Signup API

When a customer signs up in one of your products' own applications, that
application can tell Forefront. Forefront finds the customer by country code and
phone (or creates them) and opens an unassigned, high-priority "Signup" ticket
asking the sales team to schedule a call.

Each product has its own key. An Admin generates it on the product's edit page
in Forefront. The key is shown only once, and regenerating it stops the old one
working. Send the key as a bearer token:

```
POST /forefront/api/v1/signup
Authorization: Bearer <the product's key>
Content-Type: application/json

{ "name": "Priya Shah", "country_code": "+91", "phone": "98765 43210",
  "email": "priya@example.com", "external_id": "user-881" }
```

`name` and `phone` are required. `country_code` defaults to the setting above.
`email` and `external_id` (the customer's id in your application) are optional.

| Response | When |
|---|---|
| `201 {"status":"ok"}` | A ticket was opened |
| `200 {"status":"ok"}` | The customer already has an open signup ticket for this product. A note is added to it instead of opening a second ticket |
| `422 {"status":"error","errors":[...]}` | Something's missing or invalid |
| `401 {"status":"error","errors":["Invalid API key"]}` | The key is missing, wrong or was regenerated |

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
