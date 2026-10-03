# Performance Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/performance`. Managers get a sortable per-person table, Admins get a per-team table, and a Sales person sees only their own row. Every metric is defined in the spec and opens the records behind it. There's also a 12-month trend for one person.

**Architecture:**
- The page reuses the role dashboards' `Dashboard::Scope` (people, period and Product filters, never widening visibility) and `Dashboard::Metrics` (key → relation, with a drill-down at `/dashboard/metrics/:key`).
- A new query object, `Forefront::Performance`, builds the rows. Each row is a label plus a Scope narrowed to that row's people. Each value is computed from the metric relations, with averages, shares and "on time" checks done in Ruby so the SQL stays portable.
- A column registry (`Performance::COLUMNS`) drives the table, sorting and the trend.

**Tech Stack:** Rails 8.1 engine, PostgreSQL in development (SQL must stay portable to SQLite and MySQL), Pundit, Minitest integration tests.

**Spec:** `docs/superpowers/specs/2026-10-03-performance-dashboard-design.md`

## Global Constraints

- Follow `AGENTS.md`:
  - one task per commit, and each commit message says *why*;
  - test first, watch it fail, then run the full `bin/rails test` before each commit (it takes over 10 minutes, so use a long timeout);
  - run `bin/rubocop` only on the files you touched.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Keep SQL portable: no `date_trunc`, `EXTRACT`, `DATEDIFF`, `FILTER`, `ILIKE` or Postgres-only functions. Compute durations and same-day comparisons in Ruby from plucked values.
- Filters only ever narrow what a viewer may see. Every row's Scope comes from `Dashboard::Scope` (`for_member`, `with(manager_id:)`), never from raw ids.
- A rate with a zero denominator shows "—". Team rows add up numerators and denominators before dividing.
- Durations: Avg time to claim is in hours and Avg sales cycle in days, each to one decimal place.
- Target achievement keeps the existing Target rule (`Target#achieved_value`, won amounts). Collected vs target % is a separate column (agreed option C).
- Stay on branch `sales-workflow`. Do not push or merge.
- Use the domain terms in `CONTEXT.md`: Followup, Receipt, Subscription, "allocated" Products.

## Review Focus

1. **A Sales person or Manager requests `/performance/:id/trend` for someone outside their scope.** Expected: 404, not their numbers. The test is in Task 12.
2. **A record the person created themselves and then assigned to themselves.** Expected: it is not a claim. The test is in Task 2.
3. **A team row's rate where one member has many records and another has none.** Expected: the rate is Σnumerators ÷ Σdenominators, not an average of percentages. The test is in Task 11.
4. **A Lead shared 60/40, with a Receipt.** Expected: each participant's Revenue collected gets their share, and their team row gets 100%. The test is in Task 5.
5. **`?sort=` with an unknown column, or a column whose values are all "—".** Expected: the default sort or a stable order, never an exception. The test is in Task 10.

---

## File structure

| File | Responsibility |
|---|---|
| `app/queries/forefront/performance.rb` | `Performance.new(scope)`: `rows`, `columns`, `trend(person)`, `Row` and `Rate` structs, and one value method per column |
| `app/queries/forefront/dashboard/metrics.rb` | The new drill-down metrics, appended under a `# Performance` section |
| `app/queries/forefront/dashboard/scope.rb` | Task 11: `manager_id=none` (Sales persons with no Manager) |
| `app/controllers/forefront/performance_controller.rb` | `index`, `trend` |
| `app/policies/forefront/performance_policy.rb` | `index?` and `trend?` (headless, like DashboardPolicy) |
| `app/helpers/forefront/performance_helper.rb` | `performance_cell(row, column)`, `performance_sort_link(column, scope, sort, dir)` |
| `app/views/forefront/performance/index.html.erb`, `trend.html.erb` | Ranking table and trend |
| `app/views/forefront/shared/_sidebar.html.erb` | Performance link |
| `test/test_helper.rb` | `PerformanceTestHelpers` (`cell`, `row_labels`) |
| `test/integration/performance/*_test.rb` | One file per task |

---

### Task 1: The page, policy, sidebar and role visibility

**Files:**
- Create: `app/queries/forefront/performance.rb`, `app/controllers/forefront/performance_controller.rb`, `app/policies/forefront/performance_policy.rb`, `app/helpers/forefront/performance_helper.rb`, `app/views/forefront/performance/index.html.erb`
- Modify: `config/routes.rb`, `app/controllers/forefront/application_controller.rb` (`helper Forefront::PerformanceHelper`), `app/views/forefront/shared/_sidebar.html.erb`, `test/integration/sidebar_test.rb`, `test/test_helper.rb`
- Test: `test/integration/performance/visibility_test.rb`

**Interfaces:**
- Consumes: `Dashboard::Scope.from_params(viewer, params)`, `#rows`, `#for_member(admin)`, `#to_params`, `#description`; the `_filters` partial from the dashboards (`render "forefront/dashboard/filters", scope:`); `DashboardTestHelpers`.
- Produces:
  - `Forefront::Performance.new(scope)`:
    - `#rows` returns an Array of `Performance::Row` (`label`, `person` — an Admin, or nil for a team row — `scope`, `values` — a Hash keyed by column key).
    - `#columns` returns `Performance::COLUMNS`.
  - `Performance::COLUMNS` is an Array of `Performance::Column` (`key` Symbol, `title` String, `format` — one of `:count :hours :rate :money :percent :days :reasons` — `metric` String drill key, `denominator_metric` String or nil).
  - `Performance::Rate` is a Struct of `numerator` and `denominator`, with `#percent` (Float or nil) and `#+`.
  - Each `Performance#value_<key>(scope)` method returns that column's value.
  - `performance_cell(row, column)` renders `td[data-column=<key>]`.
  - Routes: `performance_path`, and `performance_trend_path(admin)` (Task 12).
  - Test helpers `cell(label, key)` (squished text) and `row_labels`.

- [ ] **Step 1: Add the test helpers**

Append to `test/test_helper.rb`:

```ruby
# For /performance: read a row's cell the way the browser shows it.
module PerformanceTestHelpers
  def cell(label, key)
    css_select("tr[data-row='#{label}'] td[data-column='#{key}']").first&.text&.squish
  end

  def row_labels
    css_select("tbody tr[data-row]").map { |row| row["data-row"] }
  end
end
```

- [ ] **Step 2: Write the failing test**

```ruby
# test/integration/performance/visibility_test.rb
require "test_helper"

class Forefront::Performance::VisibilityTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
  end

  test "a sales person sees only their own row, titled My performance, with no sort links" do
    sign_in_as(@ravi)

    get "/forefront/performance"

    assert_response :success
    assert_select "h2", "My performance"
    assert_equal [ "Ravi Rep" ], row_labels
    assert_select "thead a[href*='sort=']", count: 0
  end

  test "a manager sees their reports and themselves, and no outsiders" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_select "h2", "Performance"
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels.sort
  end

  test "a member filter outside the viewer's scope is ignored" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { member_id: @otto.id }

    assert_not_includes row_labels, "Otto Outsider"
  end

  test "the sidebar links to it for every role" do
    sign_in_as(@ravi)
    get "/forefront/"
    assert_select "aside[data-sidebar] a[href='/forefront/performance']", "My performance"

    sign_in_as(@manager)
    get "/forefront/"
    assert_select "aside[data-sidebar] [data-nav-group='Team'] a[href='/forefront/performance']", "Performance"
  end
end
```

Also update `test/integration/sidebar_test.rb`:
- the Sales person's `"main"` group becomes `[ "Dashboard", "My work", "My performance", "Notifications" ]`;
- the Manager's and Admin's `"Team"` group becomes `[ "Staff", "Performance", "Audit log" ]`.

- [ ] **Step 3: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/visibility_test.rb test/integration/sidebar_test.rb`
Expected: routing errors (no `/performance`) and sidebar assertion failures.

- [ ] **Step 4: Implement**

`config/routes.rb`, after the `my_work` route:

```ruby
  get "performance", to: "performance#index", as: :performance
```

`app/policies/forefront/performance_policy.rb`:

```ruby
module Forefront
  # /performance: everyone may open it. What each role sees is decided by
  # Dashboard::Scope (a Sales person only themselves). The trend of one
  # person is limited to the people the viewer may see.
  class PerformancePolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      true
    end

    private

    attr_reader :current_admin, :record
  end
end
```

`app/queries/forefront/performance.rb`:

```ruby
module Forefront
  # The Performance page (docs/superpowers/specs/2026-10-03-performance-dashboard-design.md):
  # one row per person (or per team, for an Admin), each a Scope narrowed to
  # that row's people, with one value per column.
  class Performance
    Column = Struct.new(:key, :title, :format, :metric, :denominator_metric, keyword_init: true)
    Row = Struct.new(:label, :person, :scope, :values, keyword_init: true)

    # A rate shown as "x of y (z%)". Team rows add the parts, then divide.
    Rate = Struct.new(:numerator, :denominator) do
      def percent
        denominator.to_i.zero? ? nil : numerator * 100.0 / denominator
      end

      def +(other)
        Rate.new(numerator + other.numerator, denominator + other.denominator)
      end
    end

    COLUMNS = [].freeze

    attr_reader :scope

    def initialize(scope)
      @scope = scope
    end

    def columns
      COLUMNS
    end

    def rows
      scope.rows.map { |person| build_row(person.name, person, scope.for_member(person)) }
    end

    private

    def build_row(label, person, row_scope)
      Row.new(label: label, person: person, scope: row_scope,
              values: columns.to_h { |column| [ column.key, public_send("value_#{column.key}", row_scope) ] })
    end
  end
end
```

`COLUMNS` starts empty. Each later task replaces the constant with the list so far plus its own columns. Keep it in spec order:

```
records_claimed, avg_time_to_claim, ticket_to_lead, lead_to_win, demos_done,
revenue_collected, shared_revenue, target_achievement, collected_vs_target,
avg_deal_size, avg_sales_cycle, followup_discipline, overdue_now,
instalment_collection, renewal_rate, lost_by_reason
```

`app/controllers/forefront/performance_controller.rb`:

```ruby
module Forefront
  # How each person (or team) is performing: a ranking for Managers and
  # Admins, and a Sales person's own numbers.
  class PerformanceController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :performance, :index?, policy_class: Forefront::PerformancePolicy
      @scope = Dashboard::Scope.from_params(current_admin, params)
      @performance = Performance.new(@scope)
      @rows = @performance.rows
    end
  end
end
```

`app/helpers/forefront/performance_helper.rb`:

```ruby
module Forefront
  module PerformanceHelper
    # One table cell, linked to the records behind its number.
    def performance_cell(row, column)
      content_tag :td, performance_value(row, column), class: "px-3 py-2 text-right whitespace-nowrap", data: { column: column.key }
    end

    private

    def performance_value(row, column)
      value = row.values[column.key]
      text = performance_text(value, column.format)
      return text if text == "—" || column.format == :reasons

      metric_link_with(text, column.metric, row.scope)
    end

    def performance_text(value, format)
      return "—" if value.nil?

      case format
      when :count then number_with_delimiter(value)
      when :money then format_money(value)
      when :hours then "#{number_with_precision(value, precision: 1)} h"
      when :days then "#{number_with_precision(value, precision: 1)} d"
      when :percent then number_to_percentage(value, precision: 0)
      when :rate then value.percent.nil? ? "—" : "#{value.numerator} of #{value.denominator} (#{number_to_percentage(value.percent, precision: 0)})"
      else value.to_s
      end
    end
  end
end
```

Add `helper Forefront::PerformanceHelper` to `ApplicationController` after the DashboardHelper line.

`app/views/forefront/performance/index.html.erb`:

```erb
<div class="mb-4">
  <h2 class="text-2xl font-bold text-gray-900"><%= current_admin.sales_person? ? "My performance" : "Performance" %></h2>
  <p class="text-sm text-gray-500"><%= @scope.description %></p>
</div>

<%= form_with url: performance_path, method: :get, local: true, class: "bg-white shadow rounded-lg p-4 mb-6 flex flex-wrap items-end gap-4" do %>
  <%= render "forefront/dashboard/filter_fields", scope: @scope %>
  <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md text-sm font-medium">Apply</button>
<% end %>

<div class="bg-white shadow rounded-lg overflow-x-auto">
  <table class="min-w-full divide-y divide-gray-200 text-sm" data-performance>
    <thead class="bg-gray-50">
      <tr>
        <th class="px-3 py-2 text-left"><%= current_admin.admin? && @scope.manager_id.nil? && @scope.member_id.nil? ? "Team" : "Person" %></th>
        <% @performance.columns.each do |column| %>
          <th class="px-3 py-2 text-right"><%= column.title %></th>
        <% end %>
      </tr>
    </thead>
    <tbody class="divide-y divide-gray-100">
      <% @rows.each do |row| %>
        <tr data-row="<%= row.label %>">
          <td class="px-3 py-2 font-medium"><%= row.label %></td>
          <% @performance.columns.each do |column| %>
            <%= performance_cell(row, column) %>
          <% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

Extract the dashboard filter bar's fields into a shared partial so both pages use them:
1. Move everything inside the `form_with` block of `app/views/forefront/dashboard/_filters.html.erb`, *except* the Apply button and the help text, into a new `app/views/forefront/dashboard/_filter_fields.html.erb`.
2. Make `_filters.html.erb` render `<%= render "forefront/dashboard/filter_fields", scope: scope %>` followed by its Apply button and help text.

The dashboard tests must still pass unchanged.

Sidebar (`app/views/forefront/shared/_sidebar.html.erb`):
- In the main group, add `<%= sidebar_link "My performance", performance_path if current_admin.sales_person? %>` after My work.
- Change the Team group to `[ [ "Staff", admins_path ], [ "Performance", performance_path ], [ "Audit log", audit_events_path ] ]`.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `bin/rails test test/integration/performance/ test/integration/sidebar_test.rb test/integration/dashboard_test.rb test/integration/dashboard/`
Expected: 0 failures.

- [ ] **Step 6: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/performance.rb app/controllers/forefront/performance_controller.rb app/policies/forefront/performance_policy.rb app/helpers/forefront/performance_helper.rb test/integration/performance test/integration/sidebar_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/controllers/forefront/performance_controller.rb app/controllers/forefront/application_controller.rb app/policies/forefront/performance_policy.rb app/helpers/forefront/performance_helper.rb app/views/forefront/performance app/views/forefront/dashboard/_filters.html.erb app/views/forefront/dashboard/_filter_fields.html.erb app/views/forefront/shared/_sidebar.html.erb config/routes.rb test/test_helper.rb test/integration/performance test/integration/sidebar_test.rb
git commit -m "Add a Performance page: each person's row, as far as the viewer may see

Managers and Admins asked to see how each individual is performing, and each
Sales person their own numbers; the page reuses the dashboards' scope so
nobody sees beyond their team. Metrics follow, one commit each.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Records claimed and Avg time to claim

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/claims_test.rb`

**Interfaces:**
- Consumes: `Scope#assignments` (Assignments to the people in view, with the Product filter), `Scope#period.times`.
- Produces:
  - metric `claims` (kind `:assignments`, periodic);
  - columns `records_claimed` (`:count`, metric `claims`) and `avg_time_to_claim` (`:hours`, metric `claims`);
  - `Performance#value_records_claimed(scope)` returns an Integer;
  - `Performance#value_avg_time_to_claim(scope)` returns a Float or nil.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/claims_test.rb
require "test_helper"

class Forefront::Performance::ClaimsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def pooled_ticket(title, created_at:)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @manager, category: "signup",
                              priority: "high", status: "open", created_at: created_at)
  end

  def take(record, by:, at:)
    travel_to(at) do
      record.assignments.create!(to_user: by, changed_by: by, from_user: nil)
      record.update_columns(assigned_to_id: by.id)
    end
  end

  test "records taken from the pool count, with the mean wait in hours; ones you created yourself don't" do
    take(pooled_ticket("Waited 2h", created_at: 3.hours.ago), by: @ravi, at: 1.hour.ago)
    take(pooled_ticket("Waited 4h", created_at: 5.hours.ago), by: @ravi, at: 1.hour.ago)
    own = Forefront::Ticket.create!(title: "Mine", description: "D", customer: @customer, created_by: @ravi, category: "request",
                                    priority: "medium", status: "open", created_at: 2.hours.ago)
    take(own, by: @ravi, at: 1.hour.ago)
    given = pooled_ticket("Given", created_at: 2.hours.ago)
    travel_to(1.hour.ago) { given.assignments.create!(to_user: @ravi, changed_by: @manager, from_user: nil) }
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "2", cell("Ravi Rep", "records_claimed")
    assert_equal "3.0 h", cell("Ravi Rep", "avg_time_to_claim")
    rows = drill(:claims, member_id: @ravi.id)
    assert_response :success
    assert_equal [ "Waited 2h", "Waited 4h" ], rows.map { |row| row[/Waited \dh/] }.sort
  end

  test "no claims shows a dash for the average" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "0", cell("Ravi Rep", "records_claimed")
    assert_equal "—", cell("Ravi Rep", "avg_time_to_claim")
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/claims_test.rb`
Expected: `cell` returns nil (no such column).

- [ ] **Step 3: Implement**

Append to `Dashboard::Metrics`, under a new `# Performance` comment:

```ruby
      # Performance
      # Taken from the pool: no previous assignee, assigned to themselves, on
      # a Ticket or Lead someone else created (your own records are never claims).
      def self.claims(scope)
        table = Assignment.table_name
        created_it = lambda do |model|
          "NOT EXISTS (SELECT 1 FROM #{model.table_name} WHERE #{model.table_name}.id = #{table}.assignable_id " \
            "AND #{table}.assignable_type = #{Assignment.connection.quote(model.name)} " \
            "AND #{model.table_name}.created_by_id = #{table}.to_user_id)"
        end
        scope.assignments.where(from_user_id: nil).where("#{table}.changed_by_id = #{table}.to_user_id")
             .where(created_at: scope.period.times).where(created_it.call(Lead)).where(created_it.call(Ticket))
      end

      define :claims, title: "Records claimed", kind: :assignments, periodic: true do |scope, _|
        claims(scope)
      end
```

In `Performance`, set:

```ruby
    COLUMNS = [
      Column.new(key: :records_claimed, title: "Records claimed", format: :count, metric: "claims"),
      Column.new(key: :avg_time_to_claim, title: "Avg time to claim", format: :hours, metric: "claims")
    ].freeze
```

and add public methods:

```ruby
    def value_records_claimed(row_scope)
      Dashboard::Metrics.claims(row_scope).count
    end

    # Hours from the record entering the pool (its creation) to being taken.
    def value_avg_time_to_claim(row_scope)
      waits = Dashboard::Metrics.claims(row_scope).includes(:assignable).map { |claim| (claim.created_at - claim.assignable.created_at) / 3600.0 }
      waits.empty? ? nil : waits.sum / waits.size
    end
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `bin/rails test test/integration/performance/`
Expected: 0 failures.

- [ ] **Step 5: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/claims_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/claims_test.rb
git commit -m "Show how much work each person claims from the pool and how fast

Claiming is the first sign someone is picking up new work; the wait from
pool entry to claim shows whether the pool is being worked promptly.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Ticket → lead rate and Lead → win rate

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`, `app/helpers/forefront/performance_helper.rb`
- Test: `test/integration/performance/rates_test.rb`

**Interfaces:**
- Consumes: `Scope#tickets`, `Scope#leads`, the existing metric `won` (Leads with `won_at` in the period), and `Performance::Rate`.
- Produces:
  - metrics `enquiries_converted`, `enquiries_handled` (kind `:tickets`), `leads_lost` and `leads_closed` (kind `:leads`), all periodic;
  - columns `ticket_to_lead` (`:rate`, metric `enquiries_converted`, denominator_metric `enquiries_handled`) and `lead_to_win` (`:rate`, metric `won`, denominator_metric `leads_closed`);
  - a `Rate` cell renders two links: the numerator to `metric`, the denominator to `denominator_metric`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/rates_test.rb
require "test_helper"

class Forefront::Performance::RatesTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def enquiry(title, category: "enquiry")
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                              category: category, priority: "medium", status: "open")
  end

  def finish(ticket, status = "resolved")
    ticket.update!(status: status)
    Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: Forefront::Ticket.statuses.fetch(status), changed_by: @ravi)
  end

  test "tickets converted out of enquiry and signup tickets finished or converted in the period" do
    converted = enquiry("Converted")
    Forefront::AuditEvent.record!(actor: @ravi, action: "converted", auditable: converted, audited_changes: {})
    finish(converted)
    finish(enquiry("Just resolved", category: "signup"), "closed")
    enquiry("Still open")
    finish(Forefront::Ticket.create!(title: "Not an enquiry", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                     category: "request", priority: "medium", status: "open"))
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "ticket_to_lead")
    assert_equal [ "Converted" ], drill(:enquiries_converted, member_id: @ravi.id).map { |row| row.split(" Acme").first }
    assert_equal [ "Converted", "Just resolved" ], drill(:enquiries_handled, member_id: @ravi.id).map { |row| row.split(" Acme").first }.sort
  end

  test "won out of won plus lost, for leads closed in the period" do
    Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                            status: "won", actual_amount: 100)
    lost = Forefront::Lead.create!(title: "Lost", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                                   status: "lost", lost_reason: Forefront::LostReason.create!(name: "Price"), lost_note: "Too dear")
    Forefront::StatusHistory.create!(trackable: lost, old_status: "Demo", new_status: "Lost", changed_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "lead_to_win")
    assert_equal 2, drill(:leads_closed, member_id: @ravi.id).size
  end

  test "nothing closed shows a dash" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "—", cell("Ravi Rep", "lead_to_win")
  end
end
```

Check `test/integration/dashboard/activity_test.rb` for how Lost Leads and StatusHistory rows are created, and match its fixtures if these fail validation. Keep the assertions.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/rates_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Metrics:

```ruby
      ENQUIRY_CATEGORIES = %w[enquiry signup].freeze

      def self.enquiries(scope)
        scope.tickets.where(category: ENQUIRY_CATEGORIES)
      end

      def self.converted_ticket_ids(scope)
        AuditEvent.where(action: "converted", auditable_type: Ticket.name, created_at: scope.period.times).select(:auditable_id)
      end

      define :enquiries_converted, title: "Enquiries converted to leads", kind: :tickets, periodic: true do |scope, _|
        enquiries(scope).where(id: converted_ticket_ids(scope))
      end

      # Converted in the period, or finished in the period without ever being converted.
      define :enquiries_handled, title: "Enquiries handled", kind: :tickets, periodic: true do |scope, _|
        finished = StatusHistory.where(trackable_type: Ticket.name, created_at: scope.period.times,
                                       new_status: [ Ticket.statuses.fetch("resolved"), Ticket.statuses.fetch("closed") ]).select(:trackable_id)
        ever_converted = AuditEvent.where(action: "converted", auditable_type: Ticket.name).select(:auditable_id)
        enquiries(scope).where(id: converted_ticket_ids(scope))
                        .or(enquiries(scope).where(id: finished).where.not(id: ever_converted))
      end

      define :leads_lost, title: "Leads lost", kind: :leads, periodic: true do |scope, reason_id|
        lost = scope.leads.where(id: StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch("lost"),
                                                         created_at: scope.period.times).select(:trackable_id))
        reason_id ? lost.where(lost_reason_id: reason_id) : lost
      end

      define :leads_closed, title: "Leads closed (won or lost)", kind: :leads, periodic: true do |scope, _|
        fetch(:won).relation(scope).or(scope.leads.where(id: fetch(:leads_lost).relation(scope).select(:id)))
      end
```

If `.or` complains that the relations aren't structurally compatible, build both sides from `scope.leads.where(id: ...)` with subselects.

Performance columns (add after `avg_time_to_claim`):

```ruby
      Column.new(key: :ticket_to_lead, title: "Ticket → lead", format: :rate, metric: "enquiries_converted", denominator_metric: "enquiries_handled"),
      Column.new(key: :lead_to_win, title: "Lead → win", format: :rate, metric: "won", denominator_metric: "leads_closed"),
```

Methods:

```ruby
    def value_ticket_to_lead(row_scope)
      rate(row_scope, "enquiries_converted", "enquiries_handled")
    end

    def value_lead_to_win(row_scope)
      rate(row_scope, "won", "leads_closed")
    end
```

and a private helper:

```ruby
    def rate(row_scope, numerator, denominator)
      Rate.new(Dashboard::Metrics.fetch(numerator).relation(row_scope).count,
               Dashboard::Metrics.fetch(denominator).relation(row_scope).count)
    end
```

In `PerformanceHelper#performance_value`, render a `:rate` cell with both links:

```ruby
      if column.format == :rate
        return safe_join([ metric_link_with(value.numerator.to_s, column.metric, row.scope), " of ",
                           metric_link_with(value.denominator.to_s, column.denominator_metric, row.scope),
                           " (#{number_to_percentage(value.percent, precision: 0)})" ])
      end
```

Place it after the `"—"` early return (`performance_text` returns "—" for a zero denominator).

- [ ] **Step 4: Run the tests and watch them pass**

Run: `bin/rails test test/integration/performance/`
Expected: 0 failures.

- [ ] **Step 5: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb app/helpers/forefront/performance_helper.rb test/integration/performance/rates_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb app/helpers/forefront/performance_helper.rb test/integration/performance/rates_test.rb
git commit -m "Show each person's ticket-to-lead and lead-to-win rates

Conversion at both steps is how a Manager sees whether someone qualifies
enquiries well and closes what they take on; both parts of each rate open
their lists.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Demos done, Avg deal size, Avg sales cycle

**Files:**
- Modify: `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/deals_test.rb`

**Interfaces:**
- Consumes: the existing metrics `demos` (StatusHistory into Demo by the person in the period) and `won`.
- Produces: columns `demos_done` (`:count`, `demos`), `avg_deal_size` (`:money`, `won`) and `avg_sales_cycle` (`:days`, `won`).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/deals_test.rb
require "test_helper"

class Forefront::Performance::DealsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def won(title, amount, created_days_ago)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source,
                            status: "won", actual_amount: amount, created_at: created_days_ago.days.ago)
  end

  test "demos, average won amount and average days from created to won" do
    won("Small", 1_000, 2)
    won("Big", 3_000, 4)
    demo = Forefront::Lead.create!(title: "Demoed", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "demo")
    Forefront::StatusHistory.create!(trackable: demo, old_status: "Contacted", new_status: "Demo", changed_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1", cell("Ravi Rep", "demos_done")
    assert_equal "₹2,000.00", cell("Ravi Rep", "avg_deal_size")
    assert_equal "3.0 d", cell("Ravi Rep", "avg_sales_cycle")
    assert_equal "—", cell("Mona Manager", "avg_deal_size")
  end
end
```

Note: `won_at` is set to now when a Lead is created as won, so the cycle is about 2 and 4 days, and the mean is 3.0. If the period filter (this month) excludes a Lead created 4 days ago near a month boundary, that doesn't matter: the cycle uses `won_at` in the period, and both wins are now.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/deals_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Columns (after `lead_to_win`):

```ruby
      Column.new(key: :demos_done, title: "Demos done", format: :count, metric: "demos"),
```

Then, after the revenue and target columns that Tasks 5 and 6 add (for now, straight after `demos_done`):

```ruby
      Column.new(key: :avg_deal_size, title: "Avg deal size", format: :money, metric: "won"),
      Column.new(key: :avg_sales_cycle, title: "Avg sales cycle", format: :days, metric: "won"),
```

Methods:

```ruby
    def value_demos_done(row_scope)
      Dashboard::Metrics.fetch(:demos).relation(row_scope).count
    end

    def value_avg_deal_size(row_scope)
      won = Dashboard::Metrics.fetch(:won).relation(row_scope)
      count = won.count
      count.zero? ? nil : won.sum(:actual_amount) / count
    end

    # Days from created to won, worked out in Ruby (portable SQL).
    def value_avg_sales_cycle(row_scope)
      days = Dashboard::Metrics.fetch(:won).relation(row_scope).pluck(:created_at, :won_at).map { |created, won| (won - created) / 1.day }
      days.empty? ? nil : days.sum / days.size
    end
```

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb test/integration/performance/deals_test.rb
bin/rails test
git add app/queries/forefront/performance.rb test/integration/performance/deals_test.rb
git commit -m "Show demos given, average deal size and average sales cycle per person

Together they show whether someone wins by volume or by size, and how long
their deals take to close.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Revenue collected and Shared revenue

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/revenue_test.rb`

**Interfaces:**
- Consumes: `Scope#people_ids`, `#product_id`, `#period.dates`; `Lead#share_fraction_for(admin_id)`.
- Produces:
  - metrics `receipts_credited` and `receipts_shared` (kind `:receipts`, periodic);
  - `Dashboard::Metrics.credited_leads(scope)`;
  - columns `revenue_collected` (`:money`, `receipts_credited`) and `shared_revenue` (`:money`, `receipts_shared`);
  - `Performance#value_revenue_collected(scope)`, which Task 6 reuses.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/revenue_test.rb
require "test_helper"

class Forefront::Performance::RevenueTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @pia = dashboard_staff("Pia Partner", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def paid_lead(title, owner, amount)
    lead = Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                   source: forefront_source, status: "won", actual_amount: amount)
    payment = Forefront::Payment.create!(lead: lead, total_amount: amount)
    Forefront::Receipt.create!(payment: payment, amount: amount, received_on: Date.current, payment_method: "cash", recorded_by: owner)
    lead
  end

  test "receipts credited by share, and the shared part shown separately" do
    paid_lead("Solo", @ravi, 1_000)
    shared = paid_lead("Joint", @ravi, 10_000)
    shared.assignments.create!(to_user: @pia, changed_by: @ravi, from_user: @ravi)
    share = Forefront::LeadShare.new(lead: shared, recorded_by: @ravi)
    share.lead_share_participants.build(admin: @ravi, percentage: 60)
    share.lead_share_participants.build(admin: @pia, percentage: 40)
    share.save!
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "₹7,000.00", cell("Ravi Rep", "revenue_collected")
    assert_equal "₹6,000.00", cell("Ravi Rep", "shared_revenue")
    assert_equal "₹4,000.00", cell("Pia Partner", "revenue_collected")
    assert_equal 2, drill(:receipts_credited, member_id: @ravi.id).size
    assert_equal 1, drill(:receipts_credited, member_id: @pia.id).size
  end
end
```

Check the LeadShare validation (participants must equal the Lead's past assignees) and the Receipt validations. Adapt the fixtures if needed, keeping the amounts and assertions.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/revenue_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Metrics:

```ruby
      # Leads the people in view have credit for: their own unshared Leads,
      # and shared Leads they take part in.
      def self.credited_leads(scope)
        leads = Lead.all
        if scope.people_ids
          shared = LeadShare.select(:lead_id)
          taking_part = LeadShareParticipant.joins(:lead_share).where(admin_id: scope.people_ids).select("#{LeadShare.table_name}.lead_id")
          leads = Lead.where(assigned_to_id: scope.people_ids).where.not(id: shared).or(Lead.where(id: taking_part))
        end
        scope.product_id ? leads.where(product_id: scope.product_id) : leads
      end

      define :receipts_credited, title: "Receipts credited", kind: :receipts, periodic: true do |scope, _|
        Receipt.where(received_on: scope.period.dates, payment_id: Payment.where(lead_id: credited_leads(scope).select(:id)).select(:id))
      end

      define :receipts_shared, title: "Receipts from shared leads", kind: :receipts, periodic: true do |scope, _|
        fetch(:receipts_credited).relation(scope).where(payment_id: Payment.where(lead_id: LeadShare.select(:lead_id)).select(:id))
      end
```

Performance columns (after `demos_done`):

```ruby
      Column.new(key: :revenue_collected, title: "Revenue collected", format: :money, metric: "receipts_credited"),
      Column.new(key: :shared_revenue, title: "Shared revenue", format: :money, metric: "receipts_shared"),
```

Methods:

```ruby
    def value_revenue_collected(row_scope)
      credited(Dashboard::Metrics.fetch(:receipts_credited).relation(row_scope), row_scope)
    end

    def value_shared_revenue(row_scope)
      credited(Dashboard::Metrics.fetch(:receipts_shared).relation(row_scope), row_scope)
    end
```

Private helper:

```ruby
    # Each Receipt's amount times the row's people's combined share of its Lead.
    def credited(receipts, row_scope)
      people = row_scope.people_ids
      receipts.includes(payment: { lead: { lead_share: :lead_share_participants } }).sum do |receipt|
        lead = receipt.payment.lead
        share = people ? people.sum { |id| lead.share_fraction_for(id) } : 1
        receipt.amount * share
      end
    end
```

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/revenue_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/revenue_test.rb
git commit -m "Credit each person with their share of the money received

Revenue collected counts Receipts by each person's share of the Lead, so a
shared deal is split as agreed; the shared part is shown on its own.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Target achievement % and Collected vs target %

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/targets_test.rb`

**Interfaces:**
- Consumes: `Scope#current_targets` (an Array of Targets running today, for the people in view), `Target#achieved_value`, `#goal_value`, `#credited_leads`, `#amount?`; `value_revenue_collected`.
- Produces:
  - metric `target_credited` (kind `:leads`);
  - columns `target_achievement` (`:percent`, `target_credited`) and `collected_vs_target` (`:percent`, `receipts_credited`).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/targets_test.rb
require "test_helper"

class Forefront::Performance::TargetsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @ravi
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    Forefront::Target.create!(admin: @ravi, product: @product, metric: "amount", period: "monthly", goal_value: 10_000,
                              starts_on: Date.current.beginning_of_month)
  end

  test "target achievement uses won amounts; collected vs target uses receipts" do
    lead = Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, product: @product, status: "won", actual_amount: 5_000)
    payment = Forefront::Payment.create!(lead: lead, total_amount: 5_000)
    Forefront::Receipt.create!(payment: payment, amount: 2_000, received_on: Date.current, payment_method: "cash", recorded_by: @ravi)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "50%", cell("Ravi Rep", "target_achievement")
    assert_equal "20%", cell("Ravi Rep", "collected_vs_target")
    assert_equal "—", cell("Mona Manager", "target_achievement")
    assert_match "Won", drill(:target_credited, member_id: @ravi.id).first
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/targets_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Metric:

```ruby
      define :target_credited, title: "Won leads counted towards running targets", kind: :leads do |scope, _|
        Lead.where(id: scope.current_targets.flat_map { |target| target.credited_leads.ids })
      end
```

Columns (after `shared_revenue`):

```ruby
      Column.new(key: :target_achievement, title: "Target achievement", format: :percent, metric: "target_credited"),
      Column.new(key: :collected_vs_target, title: "Collected vs target", format: :percent, metric: "receipts_credited"),
```

Methods:

```ruby
    # The Targets page's rule (won amounts), for amount Targets running today.
    def value_target_achievement(row_scope)
      targets = row_scope.current_targets.select(&:amount?)
      goal = targets.sum(&:goal_value)
      goal.zero? ? nil : targets.sum(&:achieved_value) * 100 / goal
    end

    # Money received against the same goals (option C in the spec).
    def value_collected_vs_target(row_scope)
      goal = row_scope.current_targets.select(&:amount?).sum(&:goal_value)
      goal.zero? ? nil : value_revenue_collected(row_scope) * 100 / goal
    end
```

Only amount Targets count here (per the spec); lead-count achievement stays on the Targets page and the dashboard Target meter.

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/targets_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/targets_test.rb
git commit -m "Show target achievement on won amounts and on money collected

Targets keep counting won amounts as everywhere else; Sumit also wanted to
see money actually collected against the same goal, side by side.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Follow-up discipline and Overdue now

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/followups_test.rb`

**Interfaces:**
- Consumes: `Scope#followups`, the existing metric `overdue_followups`, and `Performance::Rate`.
- Produces:
  - metrics `followups_due` and `followups_on_time` (kind `:followups`, periodic);
  - columns `followup_discipline` (`:rate`, `followups_on_time` / `followups_due`) and `overdue_now` (`:count`, `overdue_followups`).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/followups_test.rb
require "test_helper"

class Forefront::Performance::FollowupsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi, source: forefront_source)
  end

  def followup(scheduled_for, status: "pending", completed_at: nil)
    @lead.followups.create!(assigned_to: @ravi, created_by: @ravi, followup_type: "call", scheduled_for: scheduled_for,
                            status: status, completed_at: completed_at)
  end

  test "done by the end of the scheduled day counts as on time; cancelled ones don't count at all" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      followup(Time.zone.local(2026, 10, 3, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 3, 18))
      followup(Time.zone.local(2026, 10, 4, 10), status: "completed", completed_at: Time.zone.local(2026, 10, 5, 9))
      followup(Time.zone.local(2026, 10, 6, 10))
      followup(Time.zone.local(2026, 10, 7, 10), status: "cancelled")
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 3 (33%)", cell("Ravi Rep", "followup_discipline")
      assert_equal "1", cell("Ravi Rep", "overdue_now")
      assert_equal 1, drill(:followups_on_time, member_id: @ravi.id).size
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/followups_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Metrics:

```ruby
      define :followups_due, title: "Followups due", kind: :followups, periodic: true do |scope, _|
        scope.followups.where(scheduled_for: scope.period.times).where.not(status: "cancelled")
      end

      # Completed by the end of the scheduled day (compared in Ruby: portable SQL).
      define :followups_on_time, title: "Followups done on time", kind: :followups, periodic: true do |scope, _|
        due = fetch(:followups_due).relation(scope).where.not(completed_at: nil)
        on_time = due.pluck(:id, :scheduled_for, :completed_at).select { |_, scheduled, done| done <= scheduled.end_of_day }.map(&:first)
        Followup.where(id: on_time)
      end
```

Columns (after `avg_sales_cycle`):

```ruby
      Column.new(key: :followup_discipline, title: "Follow-up discipline", format: :rate, metric: "followups_on_time", denominator_metric: "followups_due"),
      Column.new(key: :overdue_now, title: "Overdue now", format: :count, metric: "overdue_followups"),
```

Methods:

```ruby
    def value_followup_discipline(row_scope)
      rate(row_scope, "followups_on_time", "followups_due")
    end

    def value_overdue_now(row_scope)
      Dashboard::Metrics.fetch(:overdue_followups).relation(row_scope).count
    end
```

`Followup.where(status: "cancelled")` works because the enum maps the key to "Cancelled". Check `Followup` has `completed_at`; the schema says it does.

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/followups_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/followups_test.rb
git commit -m "Show how reliably each person keeps their followups

Followups done on the day they were due, out of those due, plus what's
overdue right now, is the clearest sign of discipline with customers.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Instalment collection and Renewal rate

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`, `app/queries/forefront/performance.rb`
- Test: `test/integration/performance/collection_test.rb`

**Interfaces:**
- Consumes: `Scope#installments`, `Scope#tickets`, `Performance::Rate`.
- Produces:
  - metrics `instalments_due`, `instalments_on_time` (kind `:installments`), `renewals_closed` and `renewals_renewed` (kind `:tickets`), all periodic;
  - columns `instalment_collection` and `renewal_rate` (both `:rate`).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/collection_test.rb
require "test_helper"

class Forefront::Performance::CollectionTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  test "instalments paid by their due date out of those due" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                     source: forefront_source, status: "won", actual_amount: 30_000)
      payment = Forefront::Payment.create!(lead: lead, total_amount: 30_000)
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 5)).update_columns(status: "paid", paid_at: Time.zone.local(2026, 10, 5, 9))
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 10)).update_columns(status: "paid", paid_at: Time.zone.local(2026, 10, 12, 9))
      payment.installments.create!(amount: 10_000, due_on: Date.new(2026, 10, 15))
      sign_in_as(@manager)

      get "/forefront/performance"

      assert_equal "1 of 3 (33%)", cell("Ravi Rep", "instalment_collection")
    end
  end

  test "renewal tickets renewed out of those closed with an outcome" do
    product = Forefront::Product.create!(name: "Widget")
    [ "renewed", "declined", nil ].each_with_index do |outcome, index|
      ticket = Forefront::Ticket.create!(title: "Renewal #{index}", description: "D", customer: @customer, product: product, created_by: @ravi,
                                         assigned_to: @ravi, category: "plan_expired", priority: "medium", status: "resolved", renewal_outcome: outcome)
      Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: "Resolved", changed_by: @ravi)
    end
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "1 of 2 (50%)", cell("Ravi Rep", "renewal_rate")
  end
end
```

`update_columns` sets paid state directly. Installments become paid through Receipts, but this test is about the date comparison. Check the Installment status values (`"paid"` may be stored as `"Paid"`) and use the enum key through `update_columns(status: Forefront::Installment.statuses.fetch("paid"))` if needed.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/collection_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Metrics:

```ruby
      define :instalments_due, title: "Instalments due", kind: :installments, periodic: true do |scope, _|
        scope.installments.where(due_on: scope.period.dates)
      end

      define :instalments_on_time, title: "Instalments paid on time", kind: :installments, periodic: true do |scope, _|
        paid = fetch(:instalments_due).relation(scope).where.not(paid_at: nil)
        Installment.where(id: paid.pluck(:id, :due_on, :paid_at).select { |_, due, paid_at| paid_at.to_date <= due }.map(&:first))
      end

      define :renewals_closed, title: "Renewal tickets closed", kind: :tickets, periodic: true do |scope, _|
        finished = StatusHistory.where(trackable_type: Ticket.name, created_at: scope.period.times,
                                       new_status: [ Ticket.statuses.fetch("resolved"), Ticket.statuses.fetch("closed") ]).select(:trackable_id)
        scope.tickets.plan_expired.where(id: finished).where.not(renewal_outcome: nil)
      end

      define :renewals_renewed, title: "Renewal tickets renewed", kind: :tickets, periodic: true do |scope, _|
        fetch(:renewals_closed).relation(scope).renewed
      end
```

Columns (after `overdue_now`):

```ruby
      Column.new(key: :instalment_collection, title: "Instalment collection", format: :rate, metric: "instalments_on_time", denominator_metric: "instalments_due"),
      Column.new(key: :renewal_rate, title: "Renewal rate", format: :rate, metric: "renewals_renewed", denominator_metric: "renewals_closed"),
```

Methods:

```ruby
    def value_instalment_collection(row_scope)
      rate(row_scope, "instalments_on_time", "instalments_due")
    end

    def value_renewal_rate(row_scope)
      rate(row_scope, "renewals_renewed", "renewals_closed")
    end
```

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/collection_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/queries/forefront/dashboard/metrics.rb test/integration/performance/collection_test.rb
git commit -m "Show on-time instalment collection and renewal rate per person

Money collected on time and customers kept are the two measures of how well
someone looks after what they've already sold.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Lost by reason

**Files:**
- Modify: `app/queries/forefront/performance.rb`, `app/helpers/forefront/performance_helper.rb`
- Test: `test/integration/performance/lost_reasons_test.rb`

**Interfaces:**
- Consumes: metric `leads_lost` (slice: a lost reason id), from Task 3.
- Produces: column `lost_by_reason` (`:reasons`, `leads_lost`). Its value is an Array of `[LostReason, Integer]`, at most 3, most frequent first. The cell renders each reason as `"Name (n)"`, linked to `leads_lost` sliced by that reason.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/lost_reasons_test.rb
require "test_helper"

class Forefront::Performance::LostReasonsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lose(reason)
    lead = Forefront::Lead.create!(title: "Lost to #{reason.name}", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "lost", lost_reason: reason, lost_note: "N")
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Demo", new_status: "Lost", changed_by: @ravi)
  end

  test "the top three reasons, most frequent first, each opening its leads" do
    price, timing, rival, budget = %w[Price Timing Rival Budget].map { |name| Forefront::LostReason.create!(name: name) }
    3.times { lose(price) }
    2.times { lose(timing) }
    lose(rival)
    lose(budget)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_match(/\APrice \(3\) · Timing \(2\) · (Rival|Budget) \(1\)\z/, cell("Ravi Rep", "lost_by_reason"))
    assert_equal 3, drill(:leads_lost, member_id: @ravi.id, slice: price.id).size
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/lost_reasons_test.rb`
Expected: `cell` is nil.

- [ ] **Step 3: Implement**

Column (last):

```ruby
      Column.new(key: :lost_by_reason, title: "Lost by reason", format: :reasons, metric: "leads_lost")
```

Method:

```ruby
    def value_lost_by_reason(row_scope)
      counts = Dashboard::Metrics.fetch(:leads_lost).relation(row_scope).group(:lost_reason_id).count
      reasons = LostReason.where(id: counts.keys).index_by(&:id)
      counts.sort_by { |id, count| [ -count, reasons[id]&.name.to_s ] }.first(3).filter_map { |id, count| [ reasons[id], count ] if reasons[id] }
    end
```

In `PerformanceHelper#performance_value`, before the generic link, render the reasons:

```ruby
      if column.format == :reasons
        return "—" if value.blank?

        return safe_join(value.map { |reason, count| metric_link_with("#{reason.name} (#{count})", column.metric, row.scope, slice: reason.id) }, " · ")
      end
```

Put this check before the `"—"` text check, so an empty Array renders "—".

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/helpers/forefront/performance_helper.rb test/integration/performance/lost_reasons_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/helpers/forefront/performance_helper.rb test/integration/performance/lost_reasons_test.rb
git commit -m "Show each person's top reasons for losing leads

Why someone loses deals points to what coaching they need; each reason
opens the leads lost for it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Sorting

**Files:**
- Modify: `app/queries/forefront/performance.rb`, `app/controllers/forefront/performance_controller.rb`, `app/helpers/forefront/performance_helper.rb`, `app/views/forefront/performance/index.html.erb`
- Test: `test/integration/performance/sorting_test.rb`

**Interfaces:**
- Consumes: `Performance::COLUMNS`, `Row#values`.
- Produces:
  - `Performance#sorted_rows(sort, dir)`: `sort` is a column key String or nil, `dir` is `"asc"` or `"desc"`. The default is `revenue_collected` descending; an unknown key uses the default. nil/"—" values always sort last, and ties fall back to label order.
  - `performance_sort_link(column, scope, sort, dir)` renders the header link with `data-sort=<key>`. Sales persons don't get sort links.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/sorting_test.rb
require "test_helper"

class Forefront::Performance::SortingTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    { @ravi => 1, @sara => 3 }.each do |person, demos|
      demos.times do |index|
        lead = Forefront::Lead.create!(title: "#{person.name} #{index}", description: "D", customer: customer, created_by: person,
                                       assigned_to: person, source: forefront_source, status: "demo")
        Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: "Demo", changed_by: person)
      end
    end
  end

  test "sorts by a column, both ways, with unknown columns falling back to the default" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "demos_done", dir: "desc" }
    assert_equal [ "Sara Seller", "Ravi Rep", "Mona Manager" ], row_labels

    get "/forefront/performance", params: { sort: "demos_done", dir: "asc" }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels

    get "/forefront/performance", params: { sort: "no_such_column", dir: "sideways" }
    assert_response :success
    assert_equal 3, row_labels.size
  end

  test "a column whose values are all dashes still sorts, by name" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "avg_deal_size" }

    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels
  end

  test "headers link to sorting, toggling direction on the current column" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "demos_done", dir: "desc" }

    assert_select "thead a[data-sort='demos_done'][href*='dir=asc']"
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/sorting_test.rb`
Expected: the order assertions fail.

- [ ] **Step 3: Implement**

Performance:

```ruby
    DEFAULT_SORT = "revenue_collected".freeze

    def sorted_rows(sort, dir)
      key = columns.map { |column| column.key.to_s }.include?(sort.to_s) ? sort.to_s.to_sym : DEFAULT_SORT.to_sym
      present, blank = rows.partition { |row| !sort_value(row.values[key]).nil? }
      present = present.sort_by { |row| [ sort_value(row.values[key]), row.label ] }
      present = present.reverse if dir.to_s != "asc"
      present + blank.sort_by(&:label)
    end

    private

    def sort_value(value)
      case value
      when Rate then value.percent
      when Array then value.sum { |_, count| count }.then { |total| total.zero? ? nil : total }
      else value
      end
    end
```

With `reverse`, ties come out in reverse label order when descending. That is acceptable and deterministic. If the test expects otherwise, sort by `[ -value, label ]` for desc instead. The tests above have no ties except the all-dash case, which uses `blank.sort_by(&:label)`.

The controller uses `@rows = @performance.sorted_rows(params[:sort], params[:dir])` (strings only; ignore non-String params).

Helper:

```ruby
    def performance_sort_link(column, scope, sort, dir)
      return column.title if current_admin.sales_person?

      next_dir = sort.to_s == column.key.to_s && dir.to_s != "asc" ? "asc" : "desc"
      link_to column.title, performance_path(scope.to_params.merge(sort: column.key, dir: next_dir)),
              class: "hover:underline", data: { sort: column.key }
    end
```

In the view, the header cells render `performance_sort_link(column, @scope, params[:sort], params[:dir])`.

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/controllers/forefront/performance_controller.rb app/helpers/forefront/performance_helper.rb test/integration/performance/sorting_test.rb
bin/rails test
git add app/queries/forefront/performance.rb app/controllers/forefront/performance_controller.rb app/helpers/forefront/performance_helper.rb app/views/forefront/performance/index.html.erb test/integration/performance/sorting_test.rb
git commit -m "Let Managers and Admins rank people by any performance column

A sortable table turns the numbers into a ranking for one-to-one reviews;
people with nothing to show for a column sort last rather than first.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Admin team rows and the "No manager" row

**Files:**
- Modify: `app/queries/forefront/dashboard/scope.rb`, `app/queries/forefront/performance.rb`, `app/views/forefront/performance/index.html.erb`
- Test: `test/integration/performance/teams_test.rb`, `test/queries/forefront/dashboard/scope_test.rb` (add one test)

**Interfaces:**
- Consumes: `Scope#with(manager_id:)`, `#to_params`, `#description`.
- Produces:
  - `Scope` accepts `manager_id: "none"` for Admins only. `#no_manager?` is true; `#members` returns Sales persons with no Manager; `#to_params` carries `manager_id: "none"`; `#description` says "No manager".
  - `Performance#rows` for an Admin with no Manager or member picked: one row per Manager (label = Manager's name, `person` nil, scope = `scope.with(manager_id: manager.id)`), plus a "No manager" row when any Sales person has none.
  - The team label links to `performance_path(manager_id: …)`.

- [ ] **Step 1: Write the failing tests**

Add to `test/queries/forefront/dashboard/scope_test.rb`:

```ruby
  test "an admin can narrow to sales persons with no manager; nobody else can" do
    loner = staff("Lena Loner", "sales_person")
    s = scope(@admin, manager_id: "none")
    assert s.no_manager?
    assert_includes s.people_ids, loner.id
    assert_not_includes s.people_ids, @rep.id
    assert_equal "none", s.to_params[:manager_id]
    assert_not scope(@manager, manager_id: "none").no_manager?
  end
```

(In that file, `@rep` has a Manager and `@outsider` has `@other_manager`. If `@outsider` has no Manager there, adjust the negative assertion to a person who has one.)

```ruby
# test/integration/performance/teams_test.rb
require "test_helper"

class Forefront::Performance::TeamsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @mona = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @mona)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @mona)
    @omar = dashboard_staff("Omar Manager", "manager")
    @lena = dashboard_staff("Lena Loner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def enquiry(owner, converted:)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                                       category: "enquiry", priority: "medium", status: "resolved")
    Forefront::StatusHistory.create!(trackable: ticket, old_status: "Open", new_status: "Resolved", changed_by: owner)
    Forefront::AuditEvent.record!(actor: owner, action: "converted", auditable: ticket, audited_changes: {}) if converted
  end

  test "an admin sees one row per team plus No manager, and rates add their parts" do
    enquiry(@ravi, converted: true)
    3.times { enquiry(@sara, converted: false) }
    sign_in_as(@admin)

    get "/forefront/performance"

    assert_equal [ "Mona Manager", "No manager", "Omar Manager" ], row_labels.sort
    assert_equal "1 of 4 (25%)", cell("Mona Manager", "ticket_to_lead")
    assert_select "tr[data-row='Mona Manager'] a[href*='manager_id=#{@mona.id}']"
  end

  test "clicking a team shows its people; No manager shows those without one" do
    sign_in_as(@admin)

    get "/forefront/performance", params: { manager_id: @mona.id }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels.sort

    get "/forefront/performance", params: { manager_id: "none" }
    assert_equal [ "Lena Loner" ], row_labels
  end
end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bin/rails test test/integration/performance/teams_test.rb test/queries/forefront/dashboard/scope_test.rb`
Expected: per-person rows instead of team rows, and NoMethodError `no_manager?`.

- [ ] **Step 3: Implement**

`Scope`:
- In `initialize`, before the `@manager_id` line: `@no_manager = manager_id == "none" && viewer.admin?`. Keep the existing `@manager_id` logic; `"none"` won't match a Manager.
- Add `def no_manager? = @no_manager`, written as a normal method.
- In `members`, before the `elsif manager_id` branch: `elsif no_manager? then Admin.people.where(role: "sales_person", manager_id: nil)`.
- In `people_ids`, `return nil if viewer.admin? && manager_id.nil? && !no_manager?`.
- In `to_params`, use `manager_id: (no_manager? ? "none" : manager_id)`.
- In `description`, add `parts << "No manager" if no_manager? && member_id.nil?`.
- `with` must carry it: pass `manager_id: changes.fetch(:manager_id, no_manager? ? "none" : manager_id)`.

`Performance#rows`:

```ruby
    def rows
      @rows ||= if team_rows?
                  managers = Admin.people.where(role: "manager").order(:name)
                  teams = managers.map { |manager| build_row(manager.name, nil, scope.with(manager_id: manager.id)) }
                  loners = scope.with(manager_id: "none")
                  loners.member_ids.any? ? teams + [ build_row("No manager", nil, loners) ] : teams
                else
                  scope.rows.map { |person| build_row(person.name, person, scope.for_member(person)) }
                end
    end

    # Public: the view asks it to label the first column and link team names.
    def team_rows?
      scope.viewer.admin? && scope.manager_id.nil? && scope.member_id.nil? && !scope.no_manager?
    end
```

The view: when `@performance.team_rows?`, the label cell is a link: `link_to row.label, performance_path(row.scope.to_params.except(:member_id))`. The header reads "Team".

Rates in team rows already add their parts, because `rate` counts over the team's scope. Revenue collected for a team row uses `credited` with the team's `people_ids`, which sums each member's share (at most 100%).

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/ test/queries/forefront/dashboard/ test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard/scope.rb app/queries/forefront/performance.rb test/integration/performance/teams_test.rb test/queries/forefront/dashboard/scope_test.rb
bin/rails test
git add app/queries/forefront/dashboard/scope.rb app/queries/forefront/performance.rb app/views/forefront/performance/index.html.erb test/integration/performance/teams_test.rb test/queries/forefront/dashboard/scope_test.rb
git commit -m "Show Admins one performance row per team, then its people on click

Admins compare teams first and individuals second; Sales persons without a
Manager get their own row so nobody drops out of the totals.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: The trend page

**Files:**
- Modify: `config/routes.rb`, `app/controllers/forefront/performance_controller.rb`, `app/policies/forefront/performance_policy.rb`, `app/queries/forefront/performance.rb`, `app/views/forefront/performance/index.html.erb`
- Create: `app/views/forefront/performance/trend.html.erb`
- Test: `test/integration/performance/trend_test.rb`

**Interfaces:**
- Consumes: `Dashboard::Period.for_dates`, `Scope#with(period:)`, `#for_member`, `#member_ids`; `performance_cell`.
- Produces:
  - route `performance_trend_path(admin)` → `/performance/:id/trend`;
  - `Performance#trend(person, today: Date.current)` returns 12 Rows, oldest first, each labelled `"Oct 2026"` with that month's custom-period scope;
  - `Performance::TREND_COLUMNS` (COLUMNS without `overdue_now`, `target_achievement` and `collected_vs_target`);
  - `PerformancePolicy#trend?(person)`, true when the person is in `Dashboard::Scope.new(viewer, period:).member_ids`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/performance/trend_test.rb
require "test_helper"

class Forefront::Performance::TrendTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "demo")
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: "Demo", changed_by: @ravi, created_at: 1.month.ago)
  end

  test "twelve months, oldest first, each month's own numbers" do
    sign_in_as(@manager)

    get "/forefront/performance/#{@ravi.id}/trend"

    assert_response :success
    labels = row_labels
    assert_equal 12, labels.size
    assert_equal Date.current.strftime("%b %Y"), labels.last
    assert_equal "1", cell(1.month.ago.to_date.strftime("%b %Y"), "demos_done")
    assert_equal "0", cell(Date.current.strftime("%b %Y"), "demos_done")
    assert_select "td[data-column='overdue_now']", count: 0
  end

  test "a sales person sees their own trend, and nobody sees a trend outside their scope" do
    sign_in_as(@ravi)
    get "/forefront/performance/#{@ravi.id}/trend"
    assert_response :success

    get "/forefront/performance/#{@otto.id}/trend"
    assert_response :not_found

    sign_in_as(@manager)
    get "/forefront/performance/#{@otto.id}/trend"
    assert_response :not_found
  end

  test "names on the ranking open their trend" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_select "tr[data-row='Ravi Rep'] a[href='/forefront/performance/#{@ravi.id}/trend']"
  end
end
```

The trend table reuses `tr[data-row=<month label>]`, so `row_labels` and `cell` work unchanged.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/performance/trend_test.rb`
Expected: routing error.

- [ ] **Step 3: Implement**

Route: `get "performance/:id/trend", to: "performance#trend", as: :performance_trend`.

Policy:

```ruby
    # record: the Admin whose trend is asked for.
    def trend?
      Dashboard::Scope.new(current_admin, period: Dashboard::Period.from_params({})).member_ids.include?(record.id)
    end
```

Controller:

```ruby
    def trend
      @person = Admin.people.find(params[:id])
      raise ActiveRecord::RecordNotFound unless PerformancePolicy.new(current_admin, @person).trend?

      authorize @person, :trend?, policy_class: Forefront::PerformancePolicy
      @scope = Dashboard::Scope.from_params(current_admin, params.permit(:product_id))
      @performance = Performance.new(@scope)
      @rows = @performance.trend(@person)
    end
```

Performance:

```ruby
    TREND_COLUMNS = COLUMNS.reject { |column| %i[overdue_now target_achievement collected_vs_target].include?(column.key) }.freeze

    def trend(person, today: Date.current)
      first = today.beginning_of_month << 11
      (0..11).map do |offset|
        month = first >> offset
        month_scope = scope.with(period: Dashboard::Period.for_dates(month..month.end_of_month)).for_member(person)
        Row.new(label: month.strftime("%b %Y"), person: person, scope: month_scope,
                values: TREND_COLUMNS.to_h { |column| [ column.key, public_send("value_#{column.key}", month_scope) ] })
      end
    end
```

`trend.html.erb` has the heading "<name> · last 12 months" and a table like the index. Its header lists `Performance::TREND_COLUMNS` titles (no sort links); each row is `tr[data-row=label]` with `performance_cell(row, column)` for each column in TREND_COLUMNS. Add a "← Performance" link back.

In `index.html.erb`, when a row has a `person`, link the label to `performance_trend_path(row.person)`.

- [ ] **Step 4: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop app/queries/forefront/performance.rb app/controllers/forefront/performance_controller.rb app/policies/forefront/performance_policy.rb config/routes.rb test/integration/performance/trend_test.rb
bin/rails test
git add config/routes.rb app/controllers/forefront/performance_controller.rb app/policies/forefront/performance_policy.rb app/queries/forefront/performance.rb app/views/forefront/performance test/integration/performance/trend_test.rb
git commit -m "Show one person's performance month by month for the last year

One-to-one reviews need the trend, not just this period's snapshot; only
people the viewer may see can be opened.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Query-count guard and README

**Files:**
- Modify: `README.md` (add a "Performance" paragraph to the "Dashboards" section)
- Test: `test/integration/performance/query_count_test.rb`

**Interfaces:**
- Consumes: everything above. Read `test/integration/dashboard/query_count_test.rb` for how the dashboard counts queries (it subscribes to `sql.active_record`, skips SCHEMA and cached queries, and clears the query cache per request), and copy that approach.

- [ ] **Step 1: Write the test**

```ruby
# test/integration/performance/query_count_test.rb
require "test_helper"

class Forefront::Performance::QueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  # Copy the counting helper from test/integration/dashboard/query_count_test.rb.

  test "the manager's ranking grows by a bounded number of queries per extra person" do
    manager = dashboard_staff("Mona Manager", "manager")
    3.times { |index| dashboard_staff("Rep #{index}", "sales_person", manager: manager) }
    sign_in_as(manager)
    small = count_queries { get "/forefront/performance" }
    3.times { |index| dashboard_staff("More #{index}", "sales_person", manager: manager) }
    large = count_queries { get "/forefront/performance" }

    per_person = (large - small) / 3.0
    assert per_person <= PER_PERSON_BOUND, "#{per_person} queries per extra person (#{small} → #{large})"
  end
end
```

Measure first, then set `PER_PERSON_BOUND` to the measured value rounded up plus 20%. Record both numbers in the report. If it's above 60, note it as a concern: about 16 columns at roughly 2–4 queries each is the expected order. Don't optimise in this task.

- [ ] **Step 2: README**

After the dashboards paragraph in "## Dashboards", add:

```markdown
**Performance** (`/performance`) ranks people over the period: records claimed
and how fast, conversion and win rates, demos, revenue collected (by share
on shared deals), target achievement, deal size and cycle, follow-up and
instalment discipline, renewal rate and top lost reasons. Managers see their
team, Admins one row per team (click through to its people), and each Sales
person their own row. Click a name for that person's last 12 months.
```

- [ ] **Step 3: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/performance/
bin/rubocop test/integration/performance/query_count_test.rb
bin/rails test
git add README.md test/integration/performance/query_count_test.rb
git commit -m "Guard the Performance page's query count and describe it in the README

Each person adds a row of sixteen figures; the guard keeps that cost from
creeping up unnoticed, and host-app owners learn what the page shows.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
