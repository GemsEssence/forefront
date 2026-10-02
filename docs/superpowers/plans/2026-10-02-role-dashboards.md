# Role Dashboards (part 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dashboard at `/` with three role dashboards: My Day for Sales persons, Team for Managers (with a My Day tab), and Company for Admins. They are built only from data Forefront already records, and every number opens the list of records behind it.

**Architecture:**
- A `Dashboard::Scope` (viewer, period, Product, Manager and member filters) produces the base relations, always narrowed to the people the viewer may see.
- Each number is a `Dashboard::Metrics` entry: a key, a title, the roles allowed to open it, a record kind and a relation built from the Scope.
- Widgets render a metric's count or sum through `DashboardHelper#metric_link`, which links to `/dashboard/metrics/:key`. That page lists the same relation, so a number and its list can't disagree.

**Tech Stack:** Rails 8.1 engine, PostgreSQL in development (SQL must stay portable to SQLite and MySQL), Pundit, Kaminari, Tailwind (CDN), Minitest integration tests.

**Spec:** `docs/superpowers/specs/2026-10-02-role-dashboards-design.md`

## Global Constraints

- Follow `AGENTS.md`:
  - one task per commit, and each commit message says *why*;
  - test first, watch it fail, then run the full `bin/rails test` before each commit;
  - run `bin/rubocop` only on the files you touched.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Keep SQL portable: no `date_trunc`, `FILTER`, `ILIKE` or Postgres-only functions. Group by month in Ruby.
- People in scope:
  - Sales person: themselves.
  - Manager: their direct reports and themselves (on the My Day tab, only themselves).
  - Admin: everyone. `people_ids` is `nil`, meaning no person filter, until a Manager or member is picked.
- Filters never widen visibility. A `product_id`, `manager_id` or `member_id` the viewer can't use is ignored.
- Lead stage slices are enum keys (`"demo"`). `StatusHistory.new_status` stores database values (`"Demo"`), so convert with `Lead.statuses.fetch(key)`.
- Stay on branch `sales-workflow`. Do not push or merge.
- Use the domain terms in `CONTEXT.md`: Followup, Receipt, Subscription, "allocated" Products.

## Review Focus

1. **A `member_id` or `manager_id` from outside the viewer's team is passed in the URL.** Expected: it is ignored and the viewer sees their normal scope, never another team's numbers. The test is in Task 1 (Scope) and Task 3 (drill-down).
2. **A Sales person opens a team-only or admin-only metric URL directly**, for example `/dashboard/metrics/renewal_risk`. Expected: "not authorized" and a redirect, not a list. The test is in Task 3, using a manager-only metric added there.
3. **Custom period with `from` after `to`, or dates that don't parse.** Expected: the dates are swapped, or fall back to the start of this month through today. No exception. The test is in Task 1.
4. **An unknown metric key or stage slice.** Expected: an unknown key gives 404; an unknown slice gives an empty list, not every record. The tests are in Task 3 (key) and Task 4 (slice).
5. **A comparison against a previous period that had zero.** Expected: "▲ new", not a divide-by-zero error. The test is in Task 9.

---

## File structure

| File | Responsibility |
|---|---|
| `app/queries/forefront/dashboard/period.rb` | Parse the period params; dates, times, previous period, params for links, label |
| `app/queries/forefront/dashboard/scope.rb` | Viewer and filters to people in scope; base relations; `with`/`previous`/`for_member`; `to_params`; `description` |
| `app/queries/forefront/dashboard/metrics.rb` | The registry plus every metric definition, grouped by widget |
| `app/queries/forefront/dashboard/revenue_trend.rb` | Twelve monthly Receipt totals (Task 13) |
| `app/helpers/forefront/dashboard_helper.rb` | `metric_link`, `metric_change`, `subject_link` |
| `app/controllers/forefront/dashboard_controller.rb` | Pick the dashboard by role and tab; build the Scope |
| `app/controllers/forefront/dashboard_metrics_controller.rb` | Drill-down list |
| `app/policies/forefront/dashboard_policy.rb` | `index?`, and `metric?` for drill-downs |
| `app/views/forefront/dashboard/index.html.erb` | Heading, Manager tabs, filters, the chosen dashboard |
| `app/views/forefront/dashboard/_filters.html.erb` | Filter bar |
| `app/views/forefront/dashboard/_my_day.html.erb`, `_team.html.erb`, `_company.html.erb` | Widget layout for each dashboard |
| `app/views/forefront/dashboard/_widget.html.erb` | Card wrapper (`data-widget`) |
| `app/views/forefront/dashboard/widgets/_*.html.erb` | One file per widget |
| `app/views/forefront/dashboard_metrics/show.html.erb` + `_<kind>.html.erb` | Drill-down page, with one table partial per record kind |
| `test/test_helper.rb` | `DashboardTestHelpers` module |
| `test/queries/forefront/dashboard/period_test.rb`, `scope_test.rb` | Unit tests |
| `test/integration/dashboard_test.rb` (rewritten) and `test/integration/dashboard/*_test.rb` | Integration tests, one file per task |

Removed: `app/queries/forefront/dashboard_summary.rb`, `test/queries/forefront/dashboard_summary_test.rb`.

---

### Task 1: Period and Scope

**Files:**
- Create: `app/queries/forefront/dashboard/period.rb`
- Create: `app/queries/forefront/dashboard/scope.rb`
- Test: `test/queries/forefront/dashboard/period_test.rb`
- Test: `test/queries/forefront/dashboard/scope_test.rb`

**Interfaces:**
- Produces:
  - `Forefront::Dashboard::Period`:
    - `.from_params(params, today: Date.current)` and `.for_dates(dates)`;
    - `#name`, `#dates` (Date range), `#times` (Time range);
    - `#previous`, which is always custom;
    - `#to_params` and `#label`.
  - `Forefront::Dashboard::Scope`:
    - `.from_params(viewer, params, own: false)`;
    - `new(viewer, period:, product_id: nil, manager_id: nil, member_id: nil, own: false)`;
    - `#viewer`, `#period`, `#product_id`, `#manager_id`, `#member_id`, `#own?`;
    - `#people_ids` (Array of Integer, or nil meaning everyone);
    - `#members` (Admin relation) and `#rows` (Admins for per-person tables);
    - `#products` (Product relation);
    - `#with(**changes)`, `#previous`, `#for_member(admin)`;
    - `#to_params` (Hash) and `#description` (String);
    - `#leads` and `#tickets` (relations).

- [ ] **Step 1: Write the failing Period test**

```ruby
# test/queries/forefront/dashboard/period_test.rb
require "test_helper"

class Forefront::Dashboard::PeriodTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 14) # a Wednesday

  def period(params)
    Forefront::Dashboard::Period.from_params(params, today: TODAY)
  end

  test "defaults to this month" do
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 31), period({}).dates
    assert_equal "month", period({}).name
  end

  test "named periods are the current calendar unit" do
    assert_equal TODAY..TODAY, period(period: "today").dates
    assert_equal Date.new(2026, 10, 12)..Date.new(2026, 10, 18), period(period: "week").dates
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 12, 31), period(period: "quarter").dates
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 12, 31), period(period: "year").dates
  end

  test "custom dates are inclusive, swapped when backwards, and fall back when unparseable" do
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 10), period(period: "custom", from: "2026-09-01", to: "2026-09-10").dates
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 10), period(period: "custom", from: "2026-09-10", to: "2026-09-01").dates
    assert_equal Date.new(2026, 10, 1)..TODAY, period(period: "custom", from: "rubbish", to: "").dates
  end

  test "an unknown period name is treated as this month" do
    assert_equal "month", period(period: "decade").name
  end

  test "the previous period is the calendar unit before, or the same number of days before a custom range" do
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), period(period: "month").previous.dates
    assert_equal Date.new(2026, 10, 13)..Date.new(2026, 10, 13), period(period: "today").previous.dates
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 9, 30), period(period: "quarter").previous.dates
    assert_equal Date.new(2026, 8, 22)..Date.new(2026, 8, 31), period(period: "custom", from: "2026-09-01", to: "2026-09-10").previous.dates
  end

  test "params reproduce the period, and times cover whole days" do
    assert_equal({ period: "week" }, period(period: "week").to_params)
    custom = period(period: "custom", from: "2026-09-01", to: "2026-09-10")
    assert_equal({ period: "custom", from: "2026-09-01", to: "2026-09-10" }, custom.to_params)
    assert_equal Date.new(2026, 9, 1).beginning_of_day, custom.times.begin
    assert_equal Date.new(2026, 9, 10).end_of_day, custom.times.end
    assert_equal "1 Sep 2026 – 10 Sep 2026", custom.label
    assert_equal "This week", period(period: "week").label
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/queries/forefront/dashboard/period_test.rb`
Expected: errors with `uninitialized constant Forefront::Dashboard`.

- [ ] **Step 3: Implement Period**

```ruby
# app/queries/forefront/dashboard/period.rb
module Forefront
  module Dashboard
    # The dates a dashboard covers (?period=today|week|month|quarter|year, or
    # custom with from/to), and the period before it for comparisons.
    class Period
      LABELS = {
        "today" => "Today", "week" => "This week", "month" => "This month",
        "quarter" => "This quarter", "year" => "This year", "custom" => "Custom"
      }.freeze

      attr_reader :name, :dates

      def self.from_params(params, today: Date.current)
        name = LABELS.key?(params[:period].to_s) ? params[:period].to_s : "month"
        return new(name, calendar_unit(name, today)) unless name == "custom"

        from = parse(params[:from]) || today.beginning_of_month
        to = parse(params[:to]) || today
        from, to = to, from if from > to
        for_dates(from..to)
      end

      def self.for_dates(dates)
        new("custom", dates)
      end

      def self.calendar_unit(name, day)
        case name
        when "today" then day..day
        when "week" then day.beginning_of_week..day.end_of_week
        when "month" then day.beginning_of_month..day.end_of_month
        when "quarter" then day.beginning_of_quarter..day.end_of_quarter
        when "year" then day.beginning_of_year..day.end_of_year
        end
      end

      def self.parse(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def initialize(name, dates)
        @name = name
        @dates = dates
      end

      def times
        dates.begin.beginning_of_day..dates.end.end_of_day
      end

      # Always custom, since a named period means "the current one".
      def previous
        if name == "custom"
          length = (dates.end - dates.begin).to_i + 1
          self.class.for_dates((dates.begin - length)..(dates.begin - 1))
        else
          self.class.for_dates(self.class.calendar_unit(name, dates.begin - 1))
        end
      end

      def to_params
        return { period: name } unless name == "custom"

        { period: "custom", from: dates.begin.iso8601, to: dates.end.iso8601 }
      end

      def label
        return LABELS.fetch(name) unless name == "custom"

        "#{dates.begin.strftime("%-d %b %Y")} – #{dates.end.strftime("%-d %b %Y")}"
      end
    end
  end
end
```

- [ ] **Step 4: Run the Period test and watch it pass**

Run: `bin/rails test test/queries/forefront/dashboard/period_test.rb`
Expected: 6 runs, 0 failures.

- [ ] **Step 5: Write the failing Scope test**

```ruby
# test/queries/forefront/dashboard/scope_test.rb
require "test_helper"

class Forefront::Dashboard::ScopeTest < ActiveSupport::TestCase
  setup do
    @admin = staff("Asha Admin", "admin")
    @manager = staff("Mona Manager", "manager")
    @rep = staff("Ravi Rep", "sales_person", manager: @manager)
    @other_manager = staff("Omar Manager", "manager")
    @outsider = staff("Otto Outsider", "sales_person", manager: @other_manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @other_product = Forefront::Product.create!(name: "Gadget")
  end

  def staff(name, role, manager: nil)
    Forefront::Admin.create!(name: name, email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
                             password: "password123", role: role, manager: manager)
  end

  def scope(viewer, **params)
    Forefront::Dashboard::Scope.from_params(viewer, ActionController::Parameters.new(params))
  end

  test "a sales person covers only themselves, whatever member is asked for" do
    assert_equal [ @rep.id ], scope(@rep).people_ids
    assert_equal [ @rep.id ], scope(@rep, member_id: @outsider.id.to_s).people_ids
  end

  test "a manager covers their team and themselves, can narrow to one, but not to an outsider" do
    assert_equal [ @manager.id, @rep.id ].sort, scope(@manager).people_ids.sort
    assert_equal [ @rep.id ], scope(@manager, member_id: @rep.id.to_s).people_ids
    assert_equal [ @manager.id, @rep.id ].sort, scope(@manager, member_id: @outsider.id.to_s).people_ids.sort
  end

  test "a manager's own tab covers only themselves" do
    own = Forefront::Dashboard::Scope.from_params(@manager, ActionController::Parameters.new({}), own: true)
    assert_equal [ @manager.id ], own.people_ids
  end

  test "an admin covers everyone until a manager or member is picked" do
    assert_nil scope(@admin).people_ids
    assert_equal [ @other_manager.id, @outsider.id ].sort, scope(@admin, manager_id: @other_manager.id.to_s).people_ids.sort
    assert_equal [ @outsider.id ], scope(@admin, manager_id: @other_manager.id.to_s, member_id: @outsider.id.to_s).people_ids
    assert_equal [ @other_manager.id, @outsider.id ].sort, scope(@admin, manager_id: @other_manager.id.to_s, member_id: @rep.id.to_s).people_ids.sort
  end

  test "only managers and admins can pick a manager; only admins pick any product" do
    assert_nil scope(@manager, manager_id: @other_manager.id.to_s).manager_id
    assert_nil scope(@rep, product_id: @other_product.id.to_s).product_id
    assert_equal @product.id, scope(@rep, product_id: @product.id.to_s).product_id
    assert_equal @other_product.id, scope(@admin, product_id: @other_product.id.to_s).product_id
  end

  test "leads and tickets are narrowed to the people and product" do
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    mine = Forefront::Lead.create!(title: "Mine", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source, product: @product)
    Forefront::Lead.create!(title: "Theirs", description: "D", customer: customer, created_by: @outsider, assigned_to: @outsider, source: forefront_source)

    assert_equal [ mine ], scope(@rep).leads.to_a
    assert_equal [ mine ], scope(@admin, product_id: @product.id.to_s).leads.to_a
    assert_equal 2, scope(@admin).leads.count
  end

  test "params round-trip and describe the scope" do
    s = scope(@admin, period: "week", product_id: @product.id.to_s, manager_id: @manager.id.to_s, member_id: @rep.id.to_s)
    assert_equal({ period: "week", product_id: @product.id, manager_id: @manager.id, member_id: @rep.id }, s.to_params)
    assert_equal "This week · Widget · Ravi Rep", s.description
    assert_equal [ @rep.id ], s.previous.people_ids
    assert_equal "custom", s.previous.period.name
    assert_equal [ @rep.id ], scope(@manager).for_member(@rep).people_ids
  end
end
```

- [ ] **Step 6: Run it and watch it fail**

Run: `bin/rails test test/queries/forefront/dashboard/scope_test.rb`
Expected: errors with `uninitialized constant Forefront::Dashboard::Scope`.

- [ ] **Step 7: Implement Scope**

```ruby
# app/queries/forefront/dashboard/scope.rb
module Forefront
  module Dashboard
    # What a dashboard covers: the viewer, the period, and the Product /
    # Manager / member filters. Filters only ever narrow what the viewer may
    # see (CONTEXT.md roles): one they can't use is ignored.
    class Scope
      attr_reader :viewer, :period, :product_id, :manager_id, :member_id

      def self.from_params(viewer, params, own: false)
        new(viewer, period: Period.from_params(params), product_id: params[:product_id].presence,
                    manager_id: params[:manager_id].presence, member_id: params[:member_id].presence, own: own)
      end

      def initialize(viewer, period:, product_id: nil, manager_id: nil, member_id: nil, own: false)
        @viewer = viewer
        @period = period
        @own = own && viewer.manager?
        @product_id = product_id.to_i if product_id.present? && products.exists?(id: product_id)
        @manager_id = manager_id.to_i if manager_id.present? && viewer.admin? && Admin.people.manager.exists?(id: manager_id)
        @member_id = member_id.to_i if member_id.present? && members.exists?(id: member_id)
      end

      def own?
        @own
      end

      # The ids of the people in view, or nil for the whole company (an Admin
      # with no Manager or member picked), so unassigned work still counts.
      def people_ids
        return [ member_id ] if member_id
        return nil if viewer.admin? && manager_id.nil?

        members.ids
      end

      # Who this dashboard can be narrowed to.
      def members
        if own? || viewer.sales_person?
          Admin.where(id: viewer.id)
        elsif viewer.manager?
          Admin.where(id: [ viewer.id, *viewer.direct_report_ids ])
        elsif manager_id
          Admin.people.where(id: manager_id).or(Admin.people.where(manager_id: manager_id))
        else
          Admin.people.where.not(role: "admin")
        end
      end

      # One row per person in per-person tables.
      def rows
        member_id ? Admin.where(id: member_id) : members.order(:name)
      end

      def products
        viewer.admin? ? Product.all : viewer.products
      end

      def with(**changes)
        self.class.new(viewer, period: changes.fetch(:period, period), product_id: changes.fetch(:product_id, product_id),
                               manager_id: changes.fetch(:manager_id, manager_id), member_id: changes.fetch(:member_id, member_id), own: own?)
      end

      def previous
        with(period: period.previous)
      end

      def for_member(admin)
        with(member_id: admin.id)
      end

      def to_params
        period.to_params.merge(product_id: product_id, manager_id: manager_id, member_id: member_id,
                               tab: (own? ? "my_day" : nil)).compact
      end

      def description
        parts = [ period.label ]
        parts << Product.find(product_id).name if product_id
        parts << "#{Admin.find(manager_id).name}'s team" if manager_id && member_id.nil?
        parts << Admin.find(member_id).name if member_id
        parts.join(" · ")
      end

      def leads
        narrow(Lead.all)
      end

      def tickets
        narrow(Ticket.all)
      end

      private

      def narrow(relation)
        relation = relation.where(assigned_to_id: people_ids) if people_ids
        product_id ? relation.where(product_id: product_id) : relation
      end
    end
  end
end
```

Note: `Admin.people.manager` uses the role enum scope `manager`. If `Admin` lacks enum scopes, use `where(role: "manager")`.

- [ ] **Step 8: Run both tests and watch them pass**

Run: `bin/rails test test/queries/forefront/dashboard/`
Expected: 13 runs, 0 failures.

- [ ] **Step 9: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/dashboard test/queries/forefront/dashboard
bin/rails test
git add app/queries/forefront/dashboard test/queries/forefront/dashboard
git commit -m "Add the period and scope the role dashboards are built on

Every dashboard number needs the same rules: which dates, which Product, and
whose work, never wider than the viewer may see. Putting them in one place
keeps a URL-supplied member or manager from leaking another team's figures.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Dashboard shell: pick by role, filter bar, remove the old summary

**Files:**
- Modify: `app/controllers/forefront/dashboard_controller.rb`
- Modify: `app/views/forefront/dashboard/index.html.erb` (rewrite)
- Create: `app/views/forefront/dashboard/_filters.html.erb`, `_my_day.html.erb`, `_team.html.erb`, `_company.html.erb`, `_widget.html.erb`
- Delete: `app/queries/forefront/dashboard_summary.rb`, `test/queries/forefront/dashboard_summary_test.rb`
- Modify: `test/test_helper.rb` (add `DashboardTestHelpers`)
- Test: `test/integration/dashboard_test.rb` (rewrite)

**Interfaces:**
- Consumes: `Dashboard::Scope.from_params`, `#to_params`, `#products`, `#members`.
- Produces:
  - `@scope` and `@dashboard` (`"my_day"`, `"team"` or `"company"`) in the views.
  - Every dashboard partial receives `scope:`.
  - The widget wrapper is `render layout: "forefront/dashboard/widget", locals: { title: }`, and renders `section[data-widget=<title parameterized with _>]`.
  - The test helpers `sign_in_as`, `dashboard_staff`, `metric`, `drill` and `widget`.

- [ ] **Step 1: Add the test helpers**

Append to `test/test_helper.rb`:

```ruby
# For the role dashboards: read the numbers off the page and the records
# behind them, the way the browser sees them.
module DashboardTestHelpers
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  def dashboard_staff(name, role, manager: nil)
    Forefront::Admin.create!(name: name, email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
                             password: "password123", role: role, manager: manager)
  end

  # The number a metric shows on the page just fetched (outside per-person rows unless member: is given).
  def metric(key, slice: nil, member: nil)
    selector = +"[data-metric='#{key}']"
    selector << "[data-slice='#{slice}']" if slice
    selector << (member ? "[data-member='#{member.id}']" : ":not([data-member])")
    css_select(selector).first&.text&.squish
  end

  # The rows listed behind a metric.
  def drill(key, **params)
    get "/forefront/dashboard/metrics/#{key}", params: params
    css_select("table[data-records] tbody tr").map { |row| row.text.squish }
  end

  def widget(title)
    css_select("section[data-widget='#{title}']").first
  end
end
```

- [ ] **Step 2: Write the failing shell test** (replace the whole of `test/integration/dashboard_test.rb`)

```ruby
require "test_helper"

class Forefront::DashboardTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  test "each role lands on its own dashboard" do
    sign_in_as(@rep)
    get "/forefront/"
    assert_select "h2", "My Day"

    sign_in_as(@manager)
    get "/forefront/"
    assert_select "h2", "Team"
    assert_select "a[href='/forefront/?tab=my_day']", "My Day"

    get "/forefront/", params: { tab: "my_day" }
    assert_select "h2", "My Day"

    sign_in_as(@admin)
    get "/forefront/"
    assert_select "h2", "Company"
  end

  test "the filter bar offers the periods, the viewer's products and the people they can narrow to" do
    sign_in_as(@manager)
    get "/forefront/"

    assert_select "select[name=period] option", count: 6
    assert_select "select[name=member_id] option", text: "Ravi Rep"
    assert_select "select[name=manager_id]", count: 0

    sign_in_as(@admin)
    get "/forefront/"
    assert_select "select[name=manager_id] option", text: "Mona Manager"
    assert_select "select[name=product_id] option", text: "Widget"
  end

  test "the old company-wide tiles are gone, so a sales person sees no one else's totals" do
    sign_in_as(@rep)
    get "/forefront/"

    assert_no_match "Total Tickets", response.body
    assert_no_match "Leaderboard", response.body
  end
end
```

- [ ] **Step 3: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard_test.rb`
Expected: failures on `h2` "My Day" and the filter selects.

- [ ] **Step 4: Rewrite the controller**

```ruby
# app/controllers/forefront/dashboard_controller.rb
module Forefront
  # Each role's dashboard (docs/superpowers/specs/2026-10-02-role-dashboards-design.md):
  # My Day for a Sales person, Team (plus a My Day tab) for a Manager, Company for an Admin.
  class DashboardController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :dashboard, :index?, policy_class: Forefront::DashboardPolicy
      own = current_admin.manager? && params[:tab] == "my_day"
      @scope = Dashboard::Scope.from_params(current_admin, params, own: own)
      @dashboard = if current_admin.admin? then "company"
                   elsif current_admin.manager? && !own then "team"
                   else "my_day"
                   end
    end
  end
end
```

- [ ] **Step 5: Rewrite the views**

`app/views/forefront/dashboard/index.html.erb`:

```erb
<div class="mb-4 flex flex-wrap items-center justify-between gap-3">
  <h2 class="text-2xl font-bold text-gray-900"><%= { "my_day" => "My Day", "team" => "Team", "company" => "Company" }.fetch(@dashboard) %></h2>
  <% if current_admin.manager? %>
    <nav class="flex gap-2 text-sm">
      <%= link_to "Team", root_path, class: "rounded-md px-3 py-1 #{@dashboard == 'team' ? 'bg-indigo-50 text-indigo-700' : 'text-gray-600 hover:bg-gray-100'}" %>
      <%= link_to "My Day", root_path(tab: "my_day"), class: "rounded-md px-3 py-1 #{@dashboard == 'my_day' ? 'bg-indigo-50 text-indigo-700' : 'text-gray-600 hover:bg-gray-100'}" %>
    </nav>
  <% end %>
</div>

<% if Forefront::MyWorkPolicy.new(current_admin).index? %>
  <% my_work = Forefront::MyWork.new(current_admin).sections %>
  <p class="mb-4 text-sm" data-my-work-summary>
    <%= link_to "My work", my_work_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>:
    <span class="<%= 'text-red-700 font-medium' if my_work['overdue'].any? %>"><%= my_work["overdue"].size %> overdue</span>
    · <%= my_work["today"].size %> due today · <%= my_work["next_7_days"].size %> in the next 7 days
  </p>
<% end %>

<%= render "forefront/dashboard/filters", scope: @scope %>
<%= render "forefront/dashboard/#{@dashboard}", scope: @scope %>
```

`app/views/forefront/dashboard/_filters.html.erb`:

```erb
<%= form_with url: root_path, method: :get, local: true, class: "bg-white shadow rounded-lg p-4 mb-6 flex flex-wrap items-end gap-4" do %>
  <% if scope.own? %><input type="hidden" name="tab" value="my_day"><% end %>
  <label class="text-xs font-medium text-gray-500">Period
    <%= select_tag :period, options_for_select(Forefront::Dashboard::Period::LABELS.invert, scope.period.name), class: "mt-1 block rounded-md border-gray-300 text-sm" %>
  </label>
  <label class="text-xs font-medium text-gray-500">From
    <input type="date" name="from" value="<%= scope.period.dates.begin.iso8601 %>" class="mt-1 block rounded-md border-gray-300 text-sm">
  </label>
  <label class="text-xs font-medium text-gray-500">To
    <input type="date" name="to" value="<%= scope.period.dates.end.iso8601 %>" class="mt-1 block rounded-md border-gray-300 text-sm">
  </label>
  <label class="text-xs font-medium text-gray-500">Product
    <%= select_tag :product_id, options_from_collection_for_select(scope.products.order(:name), :id, :name, scope.product_id), include_blank: "All products", class: "mt-1 block rounded-md border-gray-300 text-sm" %>
  </label>
  <% if current_admin.admin? %>
    <label class="text-xs font-medium text-gray-500">Manager
      <%= select_tag :manager_id, options_from_collection_for_select(Forefront::Admin.people.where(role: "manager").order(:name), :id, :name, scope.manager_id), include_blank: "All teams", class: "mt-1 block rounded-md border-gray-300 text-sm" %>
    </label>
  <% end %>
  <% if scope.members.count > 1 %>
    <label class="text-xs font-medium text-gray-500">Member
      <%= select_tag :member_id, options_from_collection_for_select(scope.members.order(:name), :id, :name, scope.member_id), include_blank: "Everyone", class: "mt-1 block rounded-md border-gray-300 text-sm" %>
    </label>
  <% end %>
  <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md text-sm font-medium">Apply</button>
  <p class="text-xs text-gray-500 w-full">From/To are used when Period is Custom.</p>
<% end %>
```

`app/views/forefront/dashboard/_widget.html.erb`:

```erb
<section class="bg-white shadow rounded-lg p-5" data-widget="<%= title.parameterize(separator: "_") %>">
  <h3 class="text-sm font-semibold text-gray-700 mb-3"><%= title %></h3>
  <%= yield %>
</section>
```

`_my_day.html.erb`, `_team.html.erb`:

```erb
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
</div>
```

`_company.html.erb`:

```erb
<%= render "forefront/dashboard/team", scope: scope %>
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
</div>
```

Later tasks add one `render` line each inside these grids.

- [ ] **Step 6: Delete the old summary and its test**

```bash
git rm app/queries/forefront/dashboard_summary.rb test/queries/forefront/dashboard_summary_test.rb
grep -rn "DashboardSummary" app lib test   # expect no matches
```

- [ ] **Step 7: Run the tests and watch them pass**

Run: `bin/rails test test/integration/dashboard_test.rb test/integration/my_work_test.rb test/integration/sidebar_test.rb`
Expected: 0 failures. My work's "the dashboard points to it with counts" test still passes, because the summary line is kept.

- [ ] **Step 8: Lint, run the full suite, commit**

```bash
bin/rubocop app/controllers/forefront/dashboard_controller.rb test/integration/dashboard_test.rb test/test_helper.rb
bin/rails test
git add -A app/controllers/forefront/dashboard_controller.rb app/views/forefront/dashboard test/test_helper.rb test/integration/dashboard_test.rb app/queries/forefront/dashboard_summary.rb test/queries/forefront/dashboard_summary_test.rb
git commit -m "Give each role its own dashboard with period, product and people filters

The old dashboard showed one set of tiles to everyone, including company-wide
ticket and lead totals to Sales persons. Each role now lands on its own
dashboard (My Day, Team, Company) with a filter bar limited to what they may
see; the widgets follow in later commits.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Metric registry, drill-down page and Action strip

**Files:**
- Create: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/helpers/forefront/dashboard_helper.rb`
- Create: `app/controllers/forefront/dashboard_metrics_controller.rb`
- Create: `app/views/forefront/dashboard_metrics/show.html.erb`, `_followups.html.erb`, `_assignments.html.erb`
- Create: `app/views/forefront/dashboard/widgets/_action_strip.html.erb`
- Modify: `app/policies/forefront/dashboard_policy.rb` (add `metric?`)
- Modify: `app/controllers/forefront/application_controller.rb` (`helper Forefront::DashboardHelper`)
- Modify: `app/queries/forefront/dashboard/scope.rb` (add `followups`, `assignments`)
- Modify: `config/routes.rb`
- Modify: `app/views/forefront/dashboard/_my_day.html.erb`
- Test: `test/integration/dashboard/action_strip_test.rb`

**Interfaces:**
- Consumes: `Scope#people_ids`, `#product_id`, `#period`, `#to_params`, `#description`, `#for_member`, `#previous`.
- Produces:
  - `Dashboard::Metrics.define(key, title:, kind:, roles: ALL_ROLES, periodic: false) { |scope, slice| relation }`
  - `Dashboard::Metrics.fetch(key)`, which raises KeyError, and `.find(key)`, which returns nil.
  - `Metric#relation(scope, slice = nil)` and `#open_to?(admin)`.
  - `DashboardHelper#metric_link(key, scope, slice: nil, sum: nil, money: false, member: nil)`, which renders `a[data-metric][data-slice][data-member]`.
  - `#metric_value(key, scope, slice: nil, sum: nil)` returns a Numeric.
  - `#metric_change(key, scope, slice: nil, sum: nil)` renders `span[data-change=key]` (used from Task 9).
  - `#subject_link(record)` links to a Lead, Ticket or Installment's Lead.
  - Route helper `dashboard_metric_path(key, params)`.
  - `Scope#followups` and `#assignments`.
  - Drill-down partial contract: `_<kind>.html.erb` receives `records:` and renders `table[data-records]` with a `tbody`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/action_strip_test.rb
require "test_helper"

class Forefront::Dashboard::ActionStripTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @outsider = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, owner)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner, source: forefront_source)
  end

  def followup(on, owner, at)
    on.followups.create!(assigned_to: owner, created_by: owner, followup_type: "call", scheduled_for: at)
  end

  test "overdue and due-today followups, and newly assigned work, each open their list" do
    big = lead("Big Deal", @rep)
    followup(big, @rep, 2.hours.ago)
    followup(big, @rep, Time.current.end_of_day - 1.second) # later today
    followup(lead("Otto's", @outsider), @outsider, 2.hours.ago)
    big.assignments.create!(to_user: @rep, changed_by: @manager)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:overdue_followups)
    assert_equal "1", metric(:followups_due_today)
    assert_equal "1", metric(:newly_assigned)
    assert_equal 1, drill(:overdue_followups).size
    assert_match "Big Deal", drill(:overdue_followups).first
    assert_match "Ravi Rep", drill(:newly_assigned).first
  end

  test "a sales person can't drill into someone else's records by naming them" do
    followup(lead("Otto's", @outsider), @outsider, 2.hours.ago)
    sign_in_as(@rep)

    assert_empty drill(:overdue_followups, member_id: @outsider.id)
  end

  test "an unknown metric is not found" do
    sign_in_as(@rep)
    get "/forefront/dashboard/metrics/no_such_thing"
    assert_response :not_found
  end

  test "a role can't open a metric that isn't theirs" do
    Forefront::Dashboard::Metrics.define(:managers_only_probe, title: "Probe", kind: :followups, roles: %w[manager]) { |scope, _| scope.followups }
    sign_in_as(@rep)

    get "/forefront/dashboard/metrics/managers_only_probe"

    assert_redirected_to "/forefront/"
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/action_strip_test.rb`
Expected: errors, either `uninitialized constant Forefront::Dashboard::Metrics` or a missing route.

- [ ] **Step 3: Add the Scope relations**

Add to `Scope`, above `private`:

```ruby
      # Followups on Leads or Tickets (or Installment reminders) for the people in view.
      def followups
        relation = Followup.all
        relation = relation.where(assigned_to_id: people_ids) if people_ids
        return relation unless product_id

        relation.where(followupable_type: Lead.name, followupable_id: Lead.where(product_id: product_id).select(:id))
                .or(relation.where(followupable_type: Ticket.name, followupable_id: Ticket.where(product_id: product_id).select(:id)))
      end

      # Work handed to the people in view (including work they took themselves).
      def assignments
        relation = Assignment.all
        relation = relation.where(to_user_id: people_ids) if people_ids
        return relation unless product_id

        relation.where(assignable_type: Lead.name, assignable_id: Lead.where(product_id: product_id).select(:id))
                .or(relation.where(assignable_type: Ticket.name, assignable_id: Ticket.where(product_id: product_id).select(:id)))
      end
```

- [ ] **Step 4: Create the registry with the Action strip metrics**

```ruby
# app/queries/forefront/dashboard/metrics.rb
module Forefront
  module Dashboard
    # Every number on a dashboard is a Metric: a relation built from a Scope
    # (and optionally a slice, such as a stage). The dashboard shows its count
    # or a sum over it, and /dashboard/metrics/:key lists the same relation's
    # records, so a number and its list can't disagree.
    module Metrics
      ALL_ROLES = %w[sales_person manager admin].freeze
      TEAM_ROLES = %w[manager admin].freeze

      Metric = Struct.new(:key, :title, :kind, :roles, :periodic, :build, keyword_init: true) do
        def relation(scope, slice = nil)
          build.call(scope, slice)
        end

        def open_to?(admin)
          roles.include?(admin.role)
        end
      end

      @registry = {}

      def self.define(key, title:, kind:, roles: ALL_ROLES, periodic: false, &build)
        @registry[key.to_s] = Metric.new(key: key.to_s, title: title, kind: kind, roles: roles, periodic: periodic, build: build)
      end

      def self.fetch(key)
        @registry.fetch(key.to_s)
      end

      def self.find(key)
        @registry[key.to_s]
      end

      # Action strip
      define :overdue_followups, title: "Overdue Followups", kind: :followups do |scope, _|
        scope.followups.pending.where("scheduled_for < ?", Time.current)
      end

      define :followups_due_today, title: "Followups due today", kind: :followups do |scope, _|
        scope.followups.pending.where(scheduled_for: Time.current..Time.current.end_of_day)
      end

      define :newly_assigned, title: "Newly assigned", kind: :assignments, periodic: true do |scope, _|
        scope.assignments.where(created_at: scope.period.times)
      end
    end
  end
end
```

- [ ] **Step 5: Add the policy, route, helper and controller**

`app/policies/forefront/dashboard_policy.rb`: replace `index?` and add `metric?`:

```ruby
    def index?
      true
    end

    # record: a Dashboard::Metrics::Metric
    def metric?
      record.open_to?(current_admin)
    end
```

`config/routes.rb`, after `root to: "dashboard#index"`:

```ruby
  get "dashboard/metrics/:key", to: "dashboard_metrics#show", as: :dashboard_metric
```

`app/controllers/forefront/application_controller.rb`: add `helper Forefront::DashboardHelper` after the SidebarHelper line.

```ruby
# app/helpers/forefront/dashboard_helper.rb
module Forefront
  module DashboardHelper
    # A metric's number (a count, or a sum over `sum`), linking to the records behind it.
    # member: shows the number for one person, as in per-person tables.
    def metric_link(key, scope, slice: nil, sum: nil, money: false, member: nil)
      scope = scope.for_member(member) if member
      value = metric_value(key, scope, slice: slice, sum: sum)
      link_to (money ? format_money(value) : number_with_delimiter(value)),
              dashboard_metric_path(key, scope.to_params.merge(slice: slice).compact),
              class: "hover:underline", data: { metric: key, slice: slice, member: member&.id }.compact
    end

    def metric_value(key, scope, slice: nil, sum: nil)
      relation = Dashboard::Metrics.fetch(key).relation(scope, slice)
      sum ? relation.sum(sum) : relation.count
    end

    # ▲/▼ against the previous period.
    def metric_change(key, scope, slice: nil, sum: nil)
      now = metric_value(key, scope, slice: slice, sum: sum)
      before = metric_value(key, scope.previous, slice: slice, sum: sum)
      text, colour =
        if now == before then [ "– 0%", "text-gray-500" ]
        elsif before.zero? then [ "▲ new", "text-green-700" ]
        else
          percent = ((now - before) * 100.0 / before).round
          percent.positive? ? [ "▲ #{percent}%", "text-green-700" ] : [ "▼ #{percent.abs}%", "text-red-700" ]
        end
      content_tag :span, text, class: "ml-1 text-xs #{colour}", data: { change: key }, title: "vs #{scope.previous.period.label}"
    end

    def subject_link(record)
      case record
      when Lead, Ticket then link_to record.title, record, class: "text-indigo-600 hover:underline"
      when Installment then link_to "Installment on #{record.payment.lead.title}", record.payment.lead, class: "text-indigo-600 hover:underline"
      else record.to_s
      end
    end
  end
end
```

```ruby
# app/controllers/forefront/dashboard_metrics_controller.rb
module Forefront
  # The records behind a dashboard number, built from the same metric and filters.
  class DashboardMetricsController < ApplicationController
    def show
      @metric = Dashboard::Metrics.find(params[:key]) or raise ActiveRecord::RecordNotFound
      authorize @metric, :metric?, policy_class: Forefront::DashboardPolicy
      @scope = Dashboard::Scope.from_params(current_admin, params, own: params[:tab] == "my_day")
      relation = @metric.relation(@scope, params[:slice].presence)
      @records = relation.reorder(relation.klass.arel_table[:id].desc).page(params[:page])
    end
  end
end
```

- [ ] **Step 6: Create the drill-down views**

`app/views/forefront/dashboard_metrics/show.html.erb`:

```erb
<div class="mb-4">
  <%= link_to "← Dashboard", root_path(@scope.to_params), class: "text-sm text-indigo-600 hover:underline" %>
  <h1 class="mt-2 text-2xl font-bold text-gray-900"><%= @metric.title %></h1>
  <p class="text-sm text-gray-500"><%= @scope.description %><%= " · #{params[:slice].to_s.humanize}" if params[:slice].present? %></p>
</div>
<div class="bg-white shadow rounded-lg overflow-x-auto">
  <%= render "forefront/dashboard_metrics/#{@metric.kind}", records: @records %>
</div>
<div class="mt-4"><%= paginate @records %></div>
```

`_followups.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">On</th><th class="px-4 py-2 text-left">Type</th><th class="px-4 py-2 text-left">Assigned to</th><th class="px-4 py-2 text-left">Scheduled for</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.each do |followup| %>
      <tr><td class="px-4 py-2"><%= subject_link(followup.followupable) %></td><td class="px-4 py-2"><%= followup.followup_type.humanize %></td>
          <td class="px-4 py-2"><%= followup.assigned_to&.name %></td><td class="px-4 py-2"><%= followup.scheduled_for.strftime("%-d %b %H:%M") %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_assignments.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Work</th><th class="px-4 py-2 text-left">Assigned to</th><th class="px-4 py-2 text-left">By</th><th class="px-4 py-2 text-left">When</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.each do |assignment| %>
      <tr><td class="px-4 py-2"><%= subject_link(assignment.assignable) %></td><td class="px-4 py-2"><%= assignment.to_user&.name %></td>
          <td class="px-4 py-2"><%= assignment.changed_by&.name %></td><td class="px-4 py-2"><%= assignment.created_at.strftime("%-d %b %H:%M") %></td></tr>
    <% end %>
  </tbody>
</table>
```

(If `Assignment` names its associations differently, check `app/models/forefront/assignment.rb` and use those names.)

- [ ] **Step 7: Add the widget and place it**

`app/views/forefront/dashboard/widgets/_action_strip.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Action strip" } do %>
  <dl class="grid grid-cols-3 gap-4">
    <div><dt class="text-xs text-gray-500">Overdue Followups</dt><dd class="text-2xl font-semibold text-red-700"><%= metric_link :overdue_followups, scope %></dd></div>
    <div><dt class="text-xs text-gray-500">Due today</dt><dd class="text-2xl font-semibold"><%= metric_link :followups_due_today, scope %></dd></div>
    <div><dt class="text-xs text-gray-500">Newly assigned</dt><dd class="text-2xl font-semibold"><%= metric_link :newly_assigned, scope %></dd></div>
  </dl>
<% end %>
```

In `_my_day.html.erb`, inside the grid: `<%= render "forefront/dashboard/widgets/action_strip", scope: scope %>`

- [ ] **Step 8: Run the tests and watch them pass**

Run: `bin/rails test test/integration/dashboard/action_strip_test.rb test/integration/dashboard_test.rb`
Expected: 0 failures.

- [ ] **Step 9: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb app/controllers/forefront/dashboard_metrics_controller.rb app/policies/forefront/dashboard_policy.rb config/routes.rb test/integration/dashboard
bin/rails test
git add app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb app/controllers/forefront/dashboard_metrics_controller.rb app/controllers/forefront/application_controller.rb app/policies/forefront/dashboard_policy.rb config/routes.rb app/views/forefront/dashboard_metrics app/views/forefront/dashboard test/integration/dashboard
git commit -m "Show the Action strip, with every number opening the records behind it

Defining each number once, as a metric over the dashboard's scope, lets the
dashboard and its drill-down list share one query, so a figure and the list
behind it can't disagree, and a role can only open the metrics meant for it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: My pipeline and Orphan

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard_metrics/_leads.html.erb`
- Create: `app/views/forefront/dashboard/widgets/_pipeline.html.erb`, `_orphan.html.erb`
- Modify: `app/views/forefront/dashboard/_my_day.html.erb`
- Test: `test/integration/dashboard/pipeline_test.rb`

**Interfaces:**
- Consumes: `Scope#leads`, `metric_link`.
- Produces:
  - metrics `pipeline` (slice: stage key), `pipeline_shared` (slice: stage key) and `orphan_leads`;
  - the constant `Metrics::ACTIVE_STAGES`;
  - the partial `widgets/_pipeline` with local `title:` (default "My pipeline") and `values:` (default true). Task 12 reuses it for Leads by stage.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/pipeline_test.rb
require "test_helper"

class Forefront::Dashboard::PipelineTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @partner = dashboard_staff("Pia Partner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, status: "open", amount: 1000, owner: @rep)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: owner, assigned_to: owner,
                            source: forefront_source, status: status, estimated_amount: amount, actual_amount: (amount if status == "won"))
  end

  test "open leads are counted and valued by stage, and shared ones are marked" do
    lead("A", status: "demo", amount: 1000)
    shared = lead("B", status: "demo", amount: 500)
    shared.assignments.create!(to_user: @partner, changed_by: @rep, from_user: @rep)
    share = Forefront::LeadShare.new(lead: shared, recorded_by: @rep)
    share.lead_share_participants.build(admin: @rep, percentage: 60)
    share.lead_share_participants.build(admin: @partner, percentage: 40)
    share.save!
    lead("C", status: "won")
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "2", metric(:pipeline, slice: "demo")
    assert_equal "₹1,500.00", css_select("[data-metric='pipeline'][data-slice='demo'][data-sum]").first&.text&.squish
    assert_equal "1", metric(:pipeline_shared, slice: "demo")
    assert_nil metric(:pipeline, slice: "won")
    assert_equal [ "A", "B" ], drill(:pipeline, slice: "demo").map { |row| row.split.first }.sort
  end

  test "an unknown stage lists nothing" do
    lead("A", status: "demo")
    sign_in_as(@rep)

    assert_empty drill(:pipeline, slice: "bogus")
  end

  test "open leads with no pending followup are orphans" do
    lead("Forgotten")
    lead("Looked after").followups.create!(assigned_to: @rep, created_by: @rep, followup_type: "call", scheduled_for: 1.day.from_now)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:orphan_leads)
    assert_match "Forgotten", drill(:orphan_leads).first
  end
end
```

Note: the value link is a second `metric_link` with `sum:`. Tell the two apart with `data-sum`. Add `sum: sum` to the helper's `data:` hash in this task, so `data-sum="estimated_amount"` is rendered.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/pipeline_test.rb`
Expected: KeyError `pipeline`.

- [ ] **Step 3: Add the metrics** (append inside `module Metrics`)

```ruby
      ACTIVE_STAGES = %w[open contacted demo proposal negotiation].freeze

      # My pipeline / Leads by stage
      define :pipeline, title: "Open leads", kind: :leads do |scope, stage|
        leads = scope.leads.active
        next leads if stage.nil?

        ACTIVE_STAGES.include?(stage) ? leads.where(status: stage) : leads.none
      end

      define :pipeline_shared, title: "Open leads shared with others", kind: :leads do |scope, stage|
        fetch(:pipeline).relation(scope, stage).where(id: LeadShare.select(:lead_id))
      end

      # Orphan
      define :orphan_leads, title: "Open leads with no followup", kind: :leads do |scope, _|
        scope.leads.active.where.not(id: Followup.pending.where(followupable_type: Lead.name).select(:followupable_id))
      end
```

In `DashboardHelper#metric_link`, change the data hash to `{ metric: key, slice: slice, member: member&.id, sum: sum }.compact`.

- [ ] **Step 4: Add the views**

`app/views/forefront/dashboard_metrics/_leads.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Lead</th><th class="px-4 py-2 text-left">Customer</th><th class="px-4 py-2 text-left">Stage</th><th class="px-4 py-2 text-left">Assigned to</th><th class="px-4 py-2 text-right">Amount</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.each do |lead| %>
      <tr><td class="px-4 py-2"><%= subject_link(lead) %></td><td class="px-4 py-2"><%= lead.customer.name %></td><td class="px-4 py-2"><%= lead.status.humanize %></td>
          <td class="px-4 py-2"><%= lead.assigned_to&.name || "Unassigned" %></td><td class="px-4 py-2 text-right"><%= format_money(lead.actual_amount || lead.estimated_amount || 0) %></td></tr>
    <% end %>
  </tbody>
</table>
```

`app/views/forefront/dashboard/widgets/_pipeline.html.erb`:

```erb
<% title = local_assigns.fetch(:title, "My pipeline") %>
<% values = local_assigns.fetch(:values, true) %>
<%= render layout: "forefront/dashboard/widget", locals: { title: title } do %>
  <table class="w-full text-sm">
    <thead><tr class="text-xs text-gray-500"><th class="text-left">Stage</th><th class="text-right">Leads</th><% if values %><th class="text-right">Expected value</th><% end %></tr></thead>
    <tbody>
      <% Forefront::Dashboard::Metrics::ACTIVE_STAGES.each do |stage| %>
        <tr class="border-t border-gray-100">
          <td class="py-1"><%= stage.humanize %></td>
          <td class="py-1 text-right"><%= metric_link :pipeline, scope, slice: stage %>
            <% if metric_value(:pipeline_shared, scope, slice: stage).positive? %>
              <span class="text-xs text-gray-500">(<%= metric_link :pipeline_shared, scope, slice: stage %> shared)</span>
            <% end %></td>
          <% if values %><td class="py-1 text-right"><%= metric_link :pipeline, scope, slice: stage, sum: :estimated_amount, money: true %></td><% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

`app/views/forefront/dashboard/widgets/_orphan.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Orphan" } do %>
  <p class="text-sm text-gray-600">Open leads with no followup scheduled:
    <span class="text-2xl font-semibold text-gray-900"><%= metric_link :orphan_leads, scope %></span></p>
<% end %>
```

Add both renders to `_my_day.html.erb`.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `bin/rails test test/integration/dashboard/`
Expected: 0 failures.

- [ ] **Step 6: Lint, run the full suite, commit**

```bash
bin/rubocop app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb test/integration/dashboard/pipeline_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb app/views/forefront/dashboard app/views/forefront/dashboard_metrics test/integration/dashboard/pipeline_test.rb
git commit -m "Show each person's open pipeline by stage, and leads left without a followup

Sales persons need to see where their deals are stuck and which open leads
nobody is chasing; both open the leads behind the number.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Target meter and Team target

**Files:**
- Modify: `app/models/forefront/target.rb` (add `credited_leads`, `days_left`, `daily_run_rate`)
- Modify: `app/queries/forefront/dashboard/scope.rb` (add `current_targets`)
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_target_meter.html.erb`, `_team_target.html.erb`
- Modify: `_my_day.html.erb`, `_team.html.erb`
- Test: `test/integration/dashboard/targets_test.rb`

**Interfaces:**
- Produces:
  - `Target#credited_leads`, a Lead relation of the won Leads that give this Target's admin a share of credit;
  - `Target#days_left` (Integer, at least 0) and `Target#daily_run_rate` (Numeric);
  - `Scope#current_targets`, an Array of Targets whose period includes today, for the people and Product in view;
  - metric `target_credit` (slice: target id).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/targets_test.rb
require "test_helper"

class Forefront::Dashboard::TargetsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @target = Forefront::Target.create!(admin: @rep, product: @product, metric: "amount", period: "monthly",
                                        goal_value: 10_000, starts_on: Date.current.beginning_of_month)
  end

  test "the target meter shows what's achieved, opens the credited leads, and the run rate needed" do
    Forefront::Lead.create!(title: "Won one", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, product: @product, status: "won", actual_amount: 4_000)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "₹4,000.00", metric(:target_credit, slice: @target.id)
    days_left = (Date.current.end_of_month - Date.current).to_i + 1
    assert_match "₹6,000.00 to go", widget("target_meter").text
    assert_match "#{format('%.2f', 6000.0 / days_left)}", widget("target_meter").text.delete(",")
    assert_match "Won one", drill(:target_credit, slice: @target.id).first
  end

  test "the team target totals each kind of target and shows each person's progress" do
    sign_in_as(@manager)

    get "/forefront/"

    assert_match "₹0.00 of ₹10,000.00", widget("team_target").text
    assert_match "Ravi Rep", widget("team_target").text
  end

  test "a target outside the viewer's scope can't be drilled into" do
    other = dashboard_staff("Otto Outsider", "sales_person")
    theirs = Forefront::Target.create!(admin: other, product: @product, metric: "lead_count", period: "monthly", goal_value: 3, starts_on: Date.current.beginning_of_month)
    sign_in_as(@rep)

    assert_empty drill(:target_credit, slice: theirs.id)
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/targets_test.rb`
Expected: KeyError `target_credit`.

- [ ] **Step 3: Add the Target methods** (after `achieved_value`)

```ruby
    # The won Leads behind achieved_value.
    def credited_leads
      won = product.leads.won.where(won_at: starts_on.beginning_of_day..ends_on.end_of_day)
      Lead.where(id: won.select { |lead| lead.share_fraction_for(admin_id).positive? }.map(&:id))
    end

    def days_left
      [ (ends_on - Date.current).to_i + 1, 0 ].max
    end

    # What's still needed per day to reach the goal.
    def daily_run_rate
      remaining = [ goal_value - achieved_value, 0 ].max
      days_left.zero? ? remaining : remaining / days_left
    end
```

- [ ] **Step 4: Add `Scope#current_targets` and the metric**

In Scope:

```ruby
      def current_targets
        targets = Target.includes(:admin, :product).where("starts_on <= ?", Date.current)
        targets = targets.where(admin_id: people_ids) if people_ids
        targets = targets.where(product_id: product_id) if product_id
        targets.select { |target| target.ends_on >= Date.current }
      end
```

In Metrics:

```ruby
      # Target meter / Team target
      define :target_credit, title: "Leads counted towards the target", kind: :leads do |scope, target_id|
        target = scope.current_targets.find { |current| current.id == target_id.to_i }
        target ? target.credited_leads : Lead.none
      end
```

`metric_link :target_credit` shows a count, but the meter needs the achieved *value*. So the meter renders the achieved value as the link text through a small helper method:

```ruby
    # Link text other than the metric's own count (e.g. a Target's achieved value).
    def metric_link_with(text, key, scope, slice: nil)
      link_to text, dashboard_metric_path(key, scope.to_params.merge(slice: slice).compact),
              class: "hover:underline", data: { metric: key, slice: slice }.compact
    end
```

Add this to `DashboardHelper`.

- [ ] **Step 5: Add the widgets**

`_target_meter.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Target meter" } do %>
  <% targets = scope.current_targets %>
  <% if targets.empty? %>
    <p class="text-sm text-gray-500">No target running right now.</p>
  <% end %>
  <% targets.each do |target| %>
    <% show = ->(value) { target.amount? ? format_money(value) : number_with_precision(value, precision: 1) } %>
    <div class="mb-3">
      <p class="text-sm font-medium"><%= target.product.name %> · <%= target.metric.humanize %> · <%= target.period.humanize %></p>
      <p class="text-sm"><%= metric_link_with show.call(target.achieved_value), :target_credit, scope, slice: target.id %> of <%= show.call(target.goal_value) %></p>
      <div class="h-2 bg-gray-100 rounded"><div class="h-2 bg-indigo-500 rounded" style="width: <%= target.progress_percentage %>%"></div></div>
      <p class="text-xs text-gray-500"><%= show.call([ target.goal_value - target.achieved_value, 0 ].max) %> to go · <%= show.call(target.daily_run_rate) %> a day for <%= target.days_left %> days</p>
    </div>
  <% end %>
<% end %>
```

`_team_target.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Team target" } do %>
  <% targets = scope.current_targets %>
  <% targets.group_by(&:metric).each do |metric, group| %>
    <% show = ->(value) { metric == "amount" ? format_money(value) : number_with_precision(value, precision: 1) } %>
    <p class="text-sm font-medium"><%= metric.humanize %>: <%= show.call(group.sum(&:achieved_value)) %> of <%= show.call(group.sum(&:goal_value)) %></p>
    <ul class="mb-3">
      <% group.sort_by { |target| target.admin.name }.each do |target| %>
        <li class="text-xs mt-1"><%= target.admin.name %> · <%= target.product.name %> ·
          <%= metric_link_with show.call(target.achieved_value), :target_credit, scope, slice: target.id %> of <%= show.call(target.goal_value) %>
          <div class="h-1.5 bg-gray-100 rounded"><div class="h-1.5 bg-indigo-500 rounded" style="width: <%= target.progress_percentage %>%"></div></div></li>
      <% end %>
    </ul>
  <% end %>
  <% if targets.empty? %><p class="text-sm text-gray-500">No targets running right now.</p><% end %>
<% end %>
```

Add the Target meter to `_my_day` and the Team target to `_team`.

- [ ] **Step 6: Run the tests and watch them pass**

Run: `bin/rails test test/integration/dashboard/ test/models`
Expected: 0 failures.

- [ ] **Step 7: Lint, run the full suite, commit**

```bash
bin/rubocop app/models/forefront/target.rb app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb test/integration/dashboard/targets_test.rb
bin/rails test
git add app/models/forefront/target.rb app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb app/views/forefront/dashboard test/integration/dashboard/targets_test.rb
git commit -m "Show each person's target progress and the daily pace needed to hit it

Ahead or behind is the first thing a Sales person and their Manager ask; the
achieved figure opens the won leads (own and shared credit) behind it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Shared with me

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_shared_with_me.html.erb`
- Modify: `_my_day.html.erb`
- Test: `test/integration/dashboard/shared_with_me_test.rb`

**Interfaces:**
- Produces: metric `shared_with_me` (roles sales_person and manager).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/shared_with_me_test.rb
require "test_helper"

class Forefront::Dashboard::SharedWithMeTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @owner = dashboard_staff("Olga Owner", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  test "leads someone else owns but shares with me show my percentage and next followup" do
    lead = Forefront::Lead.create!(title: "Joint Deal", description: "D", customer: @customer, created_by: @owner, assigned_to: @rep, source: forefront_source)
    lead.assignments.create!(to_user: @owner, from_user: @rep, changed_by: @rep)
    lead.update!(assigned_to: @owner)
    share = Forefront::LeadShare.new(lead: lead, recorded_by: @owner)
    share.lead_share_participants.build(admin: @owner, percentage: 70)
    share.lead_share_participants.build(admin: @rep, percentage: 30)
    share.save!
    lead.followups.create!(assigned_to: @owner, created_by: @owner, followup_type: "call", scheduled_for: Time.zone.parse("#{Date.tomorrow} 10:00"))
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:shared_with_me)
    assert_match(/Joint Deal.*30%.*#{Date.tomorrow.strftime("%-d %b")}/, widget("shared_with_me").text.squish)
    assert_match "Joint Deal", drill(:shared_with_me).first
  end

  test "an admin can't open it" do
    sign_in_as(dashboard_staff("Asha Admin", "admin"))
    get "/forefront/dashboard/metrics/shared_with_me"
    assert_redirected_to "/forefront/"
  end
end
```

Note: if the LeadShare validation needs the participants to equal `lead.past_assignees`, the setup above covers it. The Lead was first assigned to @rep and then reassigned to @owner, so both are past assignees.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/shared_with_me_test.rb`
Expected: KeyError `shared_with_me`.

- [ ] **Step 3: Add the metric**

```ruby
      # Shared with me
      define :shared_with_me, title: "Leads shared with me", kind: :leads, roles: %w[sales_person manager] do |scope, _|
        mine = LeadShareParticipant.joins(:lead_share).where(admin_id: scope.people_ids).select("forefront_lead_shares.lead_id")
        leads = Lead.where(id: mine).where.not(assigned_to_id: scope.people_ids)
        scope.product_id ? leads.where(product_id: scope.product_id) : leads
      end
```

(`people_ids` is never nil for these roles.)

- [ ] **Step 4: Add the widget**

`_shared_with_me.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Shared with me" } do %>
  <p class="text-sm text-gray-600 mb-2"><%= metric_link :shared_with_me, scope %> leads</p>
  <ul class="text-sm divide-y divide-gray-100">
    <% Forefront::Dashboard::Metrics.fetch(:shared_with_me).relation(scope).includes(lead_share: :lead_share_participants).limit(10).each do |lead| %>
      <% mine = lead.lead_share.lead_share_participants.select { |participant| scope.people_ids.include?(participant.admin_id) }.sum(&:percentage) %>
      <% next_followup = lead.followups.pending.order(:scheduled_for).first %>
      <li class="py-1"><%= subject_link(lead) %> · <%= number_to_percentage(mine, precision: 0) %>
        · <%= next_followup ? "next #{next_followup.scheduled_for.strftime("%-d %b %H:%M")}" : "no followup" %></li>
    <% end %>
  </ul>
<% end %>
```

Add it to `_my_day.html.erb`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/shared_with_me_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/shared_with_me_test.rb
git commit -m "List the leads others share with me, with my share and next followup

Joint deals are easy to forget when someone else owns them; seeing my cut and
when it's next being chased keeps them in view.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Payments due and Payments

**Files:**
- Modify: `app/queries/forefront/dashboard/scope.rb` (add `installments`, `receipts`)
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard_metrics/_installments.html.erb`, `_receipts.html.erb`
- Create: `app/views/forefront/dashboard/widgets/_payments_due.html.erb`, `_payments.html.erb`
- Modify: `_my_day.html.erb`, `_team.html.erb`
- Test: `test/integration/dashboard/payments_test.rb`

**Interfaces:**
- Produces:
  - `Scope#installments` and `Scope#receipts` (on Leads in scope);
  - metrics `awaiting_payment`, `instalments_due`, `instalments_overdue`, and `receipts_received` (periodic; slice `one_off` or `instalment` is added in Task 13);
  - `Period.from_params({ period: "today" })` is used for "received today".

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/payments_test.rb
require "test_helper"

class Forefront::Dashboard::PaymentsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def won(title)
    Forefront::Lead.create!(title: title, description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                            source: forefront_source, status: "won", actual_amount: 30_000)
  end

  test "won leads awaiting payment, and instalments due soon or overdue" do
    won("No payment yet")
    payment = Forefront::Payment.create!(lead: won("On instalments"), total_amount: 30_000)
    payment.installments.create!(amount: 10_000, due_on: 3.days.ago.to_date)
    payment.installments.create!(amount: 10_000, due_on: 3.days.from_now.to_date)
    payment.installments.create!(amount: 10_000, due_on: 30.days.from_now.to_date)
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "2", metric(:awaiting_payment)
    assert_equal "1", metric(:instalments_due)
    assert_equal "1", metric(:instalments_overdue)
    assert_match "On instalments", drill(:instalments_overdue).first
  end

  test "the team sees receipts recorded today and in the period" do
    travel_to Time.zone.local(2026, 10, 15, 12)
    payment = Forefront::Payment.create!(lead: won("Paying"), total_amount: 30_000)
    Forefront::Receipt.create!(payment: payment, amount: 5_000, received_on: Date.current, payment_method: "cash", recorded_by: @rep)
    Forefront::Receipt.create!(payment: payment, amount: 2_000, received_on: Date.current.beginning_of_month, payment_method: "cash", recorded_by: @rep)
    sign_in_as(@manager)

    get "/forefront/"

    received = widget("payments")
    assert_equal "₹5,000.00", css_select(received, "[data-metric='receipts_received'][data-period='today']").first.text.squish
    assert_match "₹7,000.00", received.text
    assert_equal 1, drill(:receipts_received, period: "today").size
  end
end
```

Note: in the received-today link the link's period differs from the dashboard's. Add `data-period` to `metric_link`'s data hash: `period: scope.period.name`. Tests look up today's figure with `[data-period='today']`.

Check `Receipt` validations before writing the test. It may require `installment` or a positive amount, and `payment_method` may be an enum with other values. Adjust the attributes to match, keeping the amounts and dates.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/payments_test.rb`
Expected: KeyError `awaiting_payment`.

- [ ] **Step 3: Add the Scope relations and metrics**

In Scope:

```ruby
      def installments
        Installment.where(payment_id: Payment.where(lead_id: leads.select(:id)).select(:id))
      end

      def receipts
        Receipt.where(payment_id: Payment.where(lead_id: leads.select(:id)).select(:id))
      end
```

In Metrics:

```ruby
      # Payments due / Payments
      define :awaiting_payment, title: "Won leads awaiting payment", kind: :leads do |scope, _|
        won = scope.leads.won
        won.where.not(id: Payment.select(:lead_id)).or(won.where(id: Payment.pending.select(:lead_id)))
      end

      define :instalments_due, title: "Instalments due in the next 7 days", kind: :installments do |scope, _|
        scope.installments.pending.where(due_on: Date.current..(Date.current + 7))
      end

      define :instalments_overdue, title: "Overdue instalments", kind: :installments do |scope, _|
        scope.installments.pending.where("due_on < ?", Date.current)
      end

      define :receipts_received, title: "Receipts", kind: :receipts, periodic: true do |scope, _|
        scope.receipts.where(received_on: scope.period.dates)
      end
```

In `metric_link`, the data hash becomes `{ metric: key, slice: slice, member: member&.id, sum: sum, period: scope.period.name }.compact`.

- [ ] **Step 4: Add the views**

`_installments.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Lead</th><th class="px-4 py-2 text-left">Assigned to</th><th class="px-4 py-2 text-left">Due</th><th class="px-4 py-2 text-right">Amount</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(payment: { lead: :assigned_to }).each do |installment| %>
      <tr><td class="px-4 py-2"><%= subject_link(installment.payment.lead) %></td><td class="px-4 py-2"><%= installment.payment.lead.assigned_to&.name %></td>
          <td class="px-4 py-2"><%= installment.due_on.strftime("%-d %b %Y") %></td><td class="px-4 py-2 text-right"><%= format_money(installment.amount) %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_receipts.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Lead</th><th class="px-4 py-2 text-left">Received</th><th class="px-4 py-2 text-left">Method</th><th class="px-4 py-2 text-left">Recorded by</th><th class="px-4 py-2 text-right">Amount</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(:recorded_by, payment: :lead).each do |receipt| %>
      <tr><td class="px-4 py-2"><%= subject_link(receipt.payment.lead) %></td><td class="px-4 py-2"><%= receipt.received_on.strftime("%-d %b %Y") %></td>
          <td class="px-4 py-2"><%= receipt.payment_method.to_s.humanize %></td><td class="px-4 py-2"><%= receipt.recorded_by&.name %></td>
          <td class="px-4 py-2 text-right"><%= format_money(receipt.amount) %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_payments_due.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Payments due" } do %>
  <dl class="grid grid-cols-3 gap-4 text-sm">
    <div><dt class="text-xs text-gray-500">Awaiting payment</dt><dd class="text-2xl font-semibold"><%= metric_link :awaiting_payment, scope %></dd></div>
    <div><dt class="text-xs text-gray-500">Instalments due (7 days)</dt><dd class="text-2xl font-semibold"><%= metric_link :instalments_due, scope %></dd>
      <dd class="text-xs"><%= metric_link :instalments_due, scope, sum: :amount, money: true %></dd></div>
    <div><dt class="text-xs text-gray-500">Overdue instalments</dt><dd class="text-2xl font-semibold text-red-700"><%= metric_link :instalments_overdue, scope %></dd>
      <dd class="text-xs"><%= metric_link :instalments_overdue, scope, sum: :amount, money: true %></dd></div>
  </dl>
<% end %>
```

`_payments.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Payments" } do %>
  <% today = scope.with(period: Forefront::Dashboard::Period.from_params({ period: "today" })) %>
  <dl class="grid grid-cols-3 gap-4 text-sm">
    <div><dt class="text-xs text-gray-500">Received today</dt><dd class="text-xl font-semibold"><%= metric_link :receipts_received, today, sum: :amount, money: true %></dd></div>
    <div><dt class="text-xs text-gray-500">Received · <%= scope.period.label %></dt><dd class="text-xl font-semibold"><%= metric_link :receipts_received, scope, sum: :amount, money: true %></dd></div>
    <div><dt class="text-xs text-gray-500">Overdue instalments</dt><dd class="text-xl font-semibold text-red-700"><%= metric_link :instalments_overdue, scope %></dd></div>
  </dl>
<% end %>
```

Add Payments due to `_my_day` and Payments to `_team`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb test/integration/dashboard/payments_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/helpers/forefront/dashboard_helper.rb app/views/forefront/dashboard app/views/forefront/dashboard_metrics test/integration/dashboard/payments_test.rb
git commit -m "Show money still to come in, and what the team has received

Won leads with no payment and instalments coming due are money nearly in
hand; Managers also need what was received today and over the period.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Renewal Tickets and Renewal risk

**Files:**
- Modify: `app/models/forefront/ticket.rb` (add `subscription_expires_on`)
- Modify: `app/queries/forefront/dashboard/scope.rb` (add `subscriptions`)
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard_metrics/_tickets.html.erb`, `_subscriptions.html.erb`
- Create: `app/views/forefront/dashboard/widgets/_renewal_tickets.html.erb`, `_renewal_risk.html.erb`
- Modify: `_my_day.html.erb`, `_team.html.erb`
- Test: `test/integration/dashboard/renewals_test.rb`

**Interfaces:**
- Produces:
  - `Ticket#subscription_expires_on`, a Date or nil;
  - `Scope#subscriptions`, the Subscriptions of Leads in scope;
  - metrics `renewal_tickets` and `renewal_risk` (TEAM_ROLES).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/renewals_test.rb
require "test_helper"

class Forefront::Dashboard::RenewalsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  # A won lead whose Subscription expires `in_days` from today.
  def subscriber(name, in_days)
    customer = Forefront::Customer.create!(name: name, phone: "555-#{rand(1000..9999)}")
    Forefront::Lead.create!(title: "#{name} deal", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: "won", actual_amount: 1000, expires_at: in_days.days.from_now.to_date)
    customer
  end

  def renewal_ticket(customer)
    Forefront::Ticket.create!(title: "Renew #{customer.name}", description: "D", customer: customer, product: @product, created_by: @rep,
                              assigned_to: @rep, category: "plan_expired", priority: "medium", status: "open")
  end

  test "my renewal tickets show days to expiry" do
    renewal_ticket(subscriber("Acme", 12))
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:renewal_tickets)
    assert_match(/Renew Acme.*12 days/, widget("renewal_tickets").text.squish)
  end

  test "subscriptions expiring within 30 days with no renewal ticket, or one nobody acted on, are at risk" do
    subscriber("No Ticket", 10)
    renewal_ticket(subscriber("Untouched", 20))
    contacted = renewal_ticket(subscriber("Contacted", 15))
    Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: contacted, audited_changes: {})
    subscriber("Far Off", 90)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "2", metric(:renewal_risk)
    assert_equal [ "No Ticket", "Untouched" ], drill(:renewal_risk).map { |row| row.split(" Widget").first }.sort
  end
end
```

Before writing the test, check how a won Lead's `expires_at` becomes a Subscription (`ensure_subscription`). Use whatever attributes it needs.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/renewals_test.rb`
Expected: KeyError `renewal_tickets`.

- [ ] **Step 3: Implement**

Ticket:

```ruby
    # For a renewal Ticket: when the Customer's Subscription to this Product runs out.
    def subscription_expires_on
      return if product_id.nil?

      Subscription.where(customer_id: customer_id, product_id: product_id).maximum(:expires_at)
    end
```

Scope:

```ruby
      def subscriptions
        Subscription.where(lead_id: leads.select(:id))
      end
```

Metrics:

```ruby
      # Renewal Tickets / Renewal risk
      define :renewal_tickets, title: "Renewal tickets", kind: :tickets do |scope, _|
        scope.tickets.plan_expired.unfinished
      end

      define :renewal_risk, title: "Renewals at risk", kind: :subscriptions, roles: TEAM_ROLES do |scope, _|
        acted_on = AuditEvent.actions.where.not(action: "created").where(auditable_type: Ticket.name).select(:auditable_id)
        contacted = Ticket.plan_expired.where(id: acted_on)
                          .where("forefront_tickets.customer_id = forefront_subscriptions.customer_id")
                          .where("forefront_tickets.product_id = forefront_subscriptions.product_id")
        scope.subscriptions.where(expires_at: Date.current..(Date.current + 30))
             .where("NOT EXISTS (#{contacted.select('1').to_sql})")
      end
```

- [ ] **Step 4: Add the views**

`_tickets.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Ticket</th><th class="px-4 py-2 text-left">Customer</th><th class="px-4 py-2 text-left">Category</th><th class="px-4 py-2 text-left">Status</th><th class="px-4 py-2 text-left">Assigned to</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(:customer, :assigned_to).each do |ticket| %>
      <tr><td class="px-4 py-2"><%= subject_link(ticket) %></td><td class="px-4 py-2"><%= ticket.customer.name %></td><td class="px-4 py-2"><%= ticket.category.humanize %></td>
          <td class="px-4 py-2"><%= ticket.status.humanize %></td><td class="px-4 py-2"><%= ticket.assigned_to&.name || "Unassigned" %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_subscriptions.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Customer</th><th class="px-4 py-2 text-left">Product</th><th class="px-4 py-2 text-left">Expires</th><th class="px-4 py-2 text-left">Sold on</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(:customer, :product, :lead).each do |subscription| %>
      <tr><td class="px-4 py-2"><%= link_to subscription.customer.name, subscription.customer, class: "text-indigo-600 hover:underline" %></td><td class="px-4 py-2"><%= subscription.product.name %></td>
          <td class="px-4 py-2"><%= subscription.expires_at.strftime("%-d %b %Y") %></td><td class="px-4 py-2"><%= subject_link(subscription.lead) %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_renewal_tickets.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Renewal tickets" } do %>
  <p class="text-sm text-gray-600 mb-2"><%= metric_link :renewal_tickets, scope %> open</p>
  <ul class="text-sm divide-y divide-gray-100">
    <% Forefront::Dashboard::Metrics.fetch(:renewal_tickets).relation(scope).limit(10).each do |ticket| %>
      <% expires = ticket.subscription_expires_on %>
      <li class="py-1"><%= subject_link(ticket) %> ·
        <% if expires.nil? %>no subscription found
        <% elsif expires >= Date.current %><%= pluralize((expires - Date.current).to_i, "day") %> to expiry
        <% else %><span class="text-red-700">lapsed <%= pluralize((Date.current - expires).to_i, "day") %> ago</span><% end %></li>
    <% end %>
  </ul>
<% end %>
```

`_renewal_risk.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Renewal risk" } do %>
  <p class="text-sm text-gray-600">Subscriptions expiring within 30 days that nobody has contacted:
    <span class="text-2xl font-semibold text-red-700"><%= metric_link :renewal_risk, scope %></span></p>
<% end %>
```

Add Renewal tickets to `_my_day` and Renewal risk to `_team`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/models/forefront/ticket.rb app/queries/forefront/dashboard test/integration/dashboard/renewals_test.rb
bin/rails test
git add app/models/forefront/ticket.rb app/queries/forefront/dashboard app/views/forefront/dashboard app/views/forefront/dashboard_metrics test/integration/dashboard/renewals_test.rb
git commit -m "Show renewal tickets with days to expiry, and renewals nobody has chased

Recurring revenue is lost quietly when a subscription runs out unnoticed;
Sales persons see how long they have, and Managers see who hasn't been contacted.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: My activity, with comparison

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard_metrics/_status_histories.html.erb`, `_audit_events.html.erb`
- Create: `app/views/forefront/dashboard/widgets/_my_activity.html.erb`
- Modify: `_my_day.html.erb`
- Test: `test/integration/dashboard/activity_test.rb`

**Interfaces:**
- Produces:
  - metrics `demos`, `proposals`, `conversions`, `won` and `lost`, all periodic;
  - the constant `Metrics::ACTIVITY` (Array of keys), reused in Task 11.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/activity_test.rb
require "test_helper"

class Forefront::Dashboard::ActivityTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(title, **attributes)
    Forefront::Lead.create!({ title: title, description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source }.merge(attributes))
  end

  def moved(lead, to, at)
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: Forefront::Lead.statuses.fetch(to), changed_by: @rep, created_at: at)
  end

  test "demos, proposals, conversions, wins and losses in the period, each against the previous period" do
    big = lead("Big Deal")
    moved(big, "demo", 2.days.ago)
    moved(lead("Old Demo"), "demo", 40.days.ago)
    moved(lead("Second"), "demo", 1.hour.ago)
    moved(big, "proposal", 1.hour.ago)
    moved(lead("Gone", status: "lost", lost_reason: Forefront::LostReason.create!(name: "Price"), lost_note: "Too dear"), "lost", 1.hour.ago)
    ticket = Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, category: "request", priority: "medium", status: "open")
    Forefront::AuditEvent.record!(actor: @rep, action: "converted", auditable: ticket, audited_changes: {})
    lead("Winner", status: "won", actual_amount: 100)
    sign_in_as(@rep)

    get "/forefront/", params: { period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 }

    assert_equal "2", metric(:demos)
    assert_equal "1", metric(:proposals)
    assert_equal "1", metric(:conversions)
    assert_equal "1", metric(:won)
    assert_equal "1", metric(:lost)
    assert_equal "▲ new", css_select("[data-change='demos']").first.text.squish
    assert_match "Big Deal", drill(:demos, period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601).join
  end

  test "a drop against the previous period shows as a fall" do
    moved(lead("A"), "demo", 10.days.ago)
    moved(lead("B"), "demo", 9.days.ago)
    moved(lead("C"), "demo", 1.day.ago)
    sign_in_as(@rep)

    get "/forefront/", params: { period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 }

    assert_equal "▼ 50%", css_select("[data-change='demos']").first.text.squish
  end
end
```

Note: if `StatusHistory` validations reject `created_at` or need other fields, check `app/models/forefront/status_history.rb` and adapt, keeping the dates.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/activity_test.rb`
Expected: KeyError `demos`.

- [ ] **Step 3: Add the metrics**

```ruby
      # My activity / Performance per person
      ACTIVITY = %i[demos proposals conversions won lost].freeze

      def self.moved_into(scope, stage, by_people:)
        moves = StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch(stage), created_at: scope.period.times)
        moves = by_people && scope.people_ids ? moves.where(changed_by_id: scope.people_ids) : moves
        leads = by_people ? (scope.product_id ? Lead.where(product_id: scope.product_id) : nil) : scope.leads
        leads ? moves.where(trackable_id: leads.select(:id)) : moves
      end

      define :demos, title: "Demos given", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "demo", by_people: true)
      end

      define :proposals, title: "Proposals sent", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "proposal", by_people: true)
      end

      define :conversions, title: "Tickets converted to leads", kind: :audit_events, periodic: true do |scope, _|
        events = AuditEvent.where(action: "converted", auditable_type: Ticket.name, created_at: scope.period.times)
        events = events.where(actor_id: scope.people_ids) if scope.people_ids
        scope.product_id ? events.where(auditable_id: Ticket.where(product_id: scope.product_id).select(:id)) : events
      end

      define :won, title: "Leads won", kind: :leads, periodic: true do |scope, _|
        scope.leads.won.where(won_at: scope.period.times)
      end

      define :lost, title: "Leads lost", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "lost", by_people: false)
      end
```

- [ ] **Step 4: Add the views**

`_status_histories.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">Lead</th><th class="px-4 py-2 text-left">From</th><th class="px-4 py-2 text-left">To</th><th class="px-4 py-2 text-left">By</th><th class="px-4 py-2 text-left">When</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(:trackable, :changed_by).each do |history| %>
      <tr><td class="px-4 py-2"><%= subject_link(history.trackable) %></td><td class="px-4 py-2"><%= history.old_status %></td><td class="px-4 py-2"><%= history.new_status %></td>
          <td class="px-4 py-2"><%= history.changed_by&.name %></td><td class="px-4 py-2"><%= history.created_at.strftime("%-d %b %H:%M") %></td></tr>
    <% end %>
  </tbody>
</table>
```

`_audit_events.html.erb`:

```erb
<table data-records class="min-w-full divide-y divide-gray-200 text-sm">
  <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left">What</th><th class="px-4 py-2 text-left">Record</th><th class="px-4 py-2 text-left">By</th><th class="px-4 py-2 text-left">When</th></tr></thead>
  <tbody class="divide-y divide-gray-100">
    <% records.includes(:actor).each do |event| %>
      <tr><td class="px-4 py-2"><%= event.action.humanize %></td><td class="px-4 py-2"><%= event.auditable ? subject_link(event.auditable) : event.auditable_label %></td>
          <td class="px-4 py-2"><%= event.actor&.name %></td><td class="px-4 py-2"><%= event.created_at.strftime("%-d %b %H:%M") %></td></tr>
    <% end %>
  </tbody>
</table>
```

(`subject_link` falls back to `record.to_s` for a Product. Check the AuditEvent association names: `actor` and polymorphic `auditable`.)

`_my_activity.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "My activity" } do %>
  <dl class="grid grid-cols-5 gap-3 text-sm">
    <% Forefront::Dashboard::Metrics::ACTIVITY.each do |key| %>
      <div><dt class="text-xs text-gray-500"><%= Forefront::Dashboard::Metrics.fetch(key).title %></dt>
        <dd class="text-xl font-semibold"><%= metric_link key, scope %><%= metric_change key, scope %></dd></div>
    <% end %>
  </dl>
<% end %>
```

Add it to `_my_day.html.erb`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/activity_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard app/views/forefront/dashboard_metrics test/integration/dashboard/activity_test.rb
git commit -m "Show demos, proposals, conversions, wins and losses against the last period

This is the self-check of how a Sales person is doing: what they moved forward
in the period and whether that's up or down on the period before.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Unassigned pool

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_unassigned_pool.html.erb`
- Modify: `_team.html.erb`
- Test: `test/integration/dashboard/unassigned_pool_test.rb`

**Interfaces:**
- Produces:
  - metrics `pool_leads` and `pool_tickets` (slice: an age bucket key);
  - metric `pool_leads_by_source` (slice: source id);
  - the constant `Metrics::AGES` (Hash of bucket key → `[newest_age, oldest_age_or_nil]`);
  - all of these are TEAM_ROLES.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/unassigned_pool_test.rb
require "test_helper"

class Forefront::Dashboard::UnassignedPoolTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def pooled_ticket(title, age)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @manager, category: "signup",
                              priority: "high", status: "open", created_at: age.ago)
  end

  test "the pool is counted by age and the oldest are listed with an Assign link" do
    pooled_ticket("Fresh", 30.minutes)
    pooled_ticket("Stale", 5.days)
    Forefront::Lead.create!(title: "Pool lead", description: "D", customer: @customer, created_by: @manager, source: forefront_source("Website"), created_at: 3.hours.ago)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", metric(:pool_tickets, slice: "under_2h")
    assert_equal "1", metric(:pool_tickets, slice: "over_3d")
    assert_equal "1", metric(:pool_leads, slice: "2h_24h")
    assert_equal "1", metric(:pool_leads_by_source, slice: forefront_source("Website").id)
    oldest = css_select(widget("unassigned_pool"), "li").map { |item| item.text.squish }
    assert_match(/\AStale.*Assign/, oldest.first)
    assert_match "Stale", drill(:pool_tickets, slice: "over_3d").first
  end

  test "a sales person can't open the team pool metrics" do
    sign_in_as(dashboard_staff("Ravi Rep", "sales_person"))
    get "/forefront/dashboard/metrics/pool_tickets"
    assert_redirected_to "/forefront/"
  end
end
```

Note: if `Lead.create!` with `assigned_to: nil` gets defaulted to its creator, look at how `test/integration/unassigned_pool_test.rb` creates pooled Leads and copy that.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/unassigned_pool_test.rb`
Expected: KeyError `pool_tickets`.

- [ ] **Step 3: Add the metrics**

```ruby
      # Unassigned pool
      AGES = { "under_2h" => [ 0.hours, 2.hours ], "2h_24h" => [ 2.hours, 24.hours ], "1d_3d" => [ 24.hours, 72.hours ], "over_3d" => [ 72.hours, nil ] }.freeze

      def self.aged(relation, bucket)
        return relation if bucket.nil?
        return relation.none unless AGES.key?(bucket)

        newest, oldest = AGES.fetch(bucket)
        table = relation.klass.table_name
        relation = relation.where("#{table}.created_at <= ?", newest.ago)
        oldest ? relation.where("#{table}.created_at > ?", oldest.ago) : relation
      end

      def self.pool(scope, model)
        work = model == Lead ? Lead.active : Ticket.unfinished
        pool = UnassignedPool.visible_to(scope.viewer, work)
        scope.product_id ? pool.where(product_id: scope.product_id) : pool
      end

      define :pool_leads, title: "Unassigned leads", kind: :leads, roles: TEAM_ROLES do |scope, bucket|
        aged(pool(scope, Lead), bucket)
      end

      define :pool_tickets, title: "Unassigned tickets", kind: :tickets, roles: TEAM_ROLES do |scope, bucket|
        aged(pool(scope, Ticket), bucket)
      end

      define :pool_leads_by_source, title: "Unassigned leads by source", kind: :leads, roles: TEAM_ROLES do |scope, source_id|
        source_id ? pool(scope, Lead).where(source_id: source_id) : pool(scope, Lead)
      end
```

- [ ] **Step 4: Add the widget**

`_unassigned_pool.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Unassigned pool" } do %>
  <table class="w-full text-sm mb-3">
    <thead><tr class="text-xs text-gray-500"><th class="text-left">Waiting</th><th class="text-right">Tickets</th><th class="text-right">Leads</th></tr></thead>
    <tbody>
      <% { "under_2h" => "Under 2 hours", "2h_24h" => "2–24 hours", "1d_3d" => "1–3 days", "over_3d" => "Over 3 days" }.each do |bucket, label| %>
        <tr class="border-t border-gray-100"><td class="py-1"><%= label %></td>
          <td class="py-1 text-right"><%= metric_link :pool_tickets, scope, slice: bucket %></td>
          <td class="py-1 text-right"><%= metric_link :pool_leads, scope, slice: bucket %></td></tr>
      <% end %>
    </tbody>
  </table>
  <p class="text-xs text-gray-500 mb-1">By product</p>
  <p class="text-sm mb-3">
    <% scope.products.order(:name).each do |product| %>
      <span class="mr-3"><%= product.name %>: <%= metric_link :pool_tickets, scope.with(product_id: product.id) %> tickets · <%= metric_link :pool_leads, scope.with(product_id: product.id) %> leads</span>
    <% end %>
  </p>
  <p class="text-xs text-gray-500 mb-1">Leads by source</p>
  <p class="text-sm mb-3">
    <% Forefront::Source.order(:name).each do |source| %>
      <% next if metric_value(:pool_leads_by_source, scope, slice: source.id).zero? %>
      <span class="mr-3"><%= source.name %>: <%= metric_link :pool_leads_by_source, scope, slice: source.id %></span>
    <% end %>
  </p>
  <p class="text-xs text-gray-500 mb-1">Oldest first</p>
  <ul class="text-sm divide-y divide-gray-100">
    <% oldest = (Forefront::Dashboard::Metrics.pool(scope, Forefront::Ticket).order(:created_at).limit(5).to_a +
                 Forefront::Dashboard::Metrics.pool(scope, Forefront::Lead).order(:created_at).limit(5).to_a).min_by(5, &:created_at) %>
    <% oldest.each do |work| %>
      <li class="py-1 flex justify-between"><span><%= work.title %> · <%= time_ago_in_words(work.created_at) %></span>
        <%= link_to "Assign", work, class: "text-indigo-600 hover:underline" %></li>
    <% end %>
  </ul>
<% end %>
```

Pool items on the per-product line are linked with `scope.with(product_id:)`. Their `data-metric` values match the bucket-less totals, so the test above reads them by slice only.

Add the widget at the top of `_team.html.erb`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/unassigned_pool_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/unassigned_pool_test.rb
git commit -m "Show Managers the unassigned pool by age, product and source, oldest first

Work nobody owns is the first thing to slip; Managers need to see how much is
waiting, how long for, and get straight to assigning the oldest.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Workload per person and Performance per person

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_workload.html.erb`, `_performance.html.erb`
- Modify: `_team.html.erb`
- Test: `test/integration/dashboard/per_person_test.rb`

**Interfaces:**
- Consumes: `Scope#rows`, `metric_link(..., member:)`, `Metrics::ACTIVITY`.
- Produces: metrics `open_tickets` and `active_leads`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/per_person_test.rb
require "test_helper"

class Forefront::Dashboard::PerPersonTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    @outsider = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def ticket(owner)
    Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: owner, assigned_to: owner, category: "request", priority: "medium", status: "open")
  end

  test "workload has one row per team member, including the manager, and no outsiders" do
    2.times { ticket(@ravi) }
    ticket(@sara)
    ticket(@outsider)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "2", metric(:open_tickets, member: @ravi)
    assert_equal "1", metric(:open_tickets, member: @sara)
    assert_equal "0", metric(:open_tickets, member: @manager)
    assert_nil metric(:open_tickets, member: @outsider)
    assert_equal 2, drill(:open_tickets, member_id: @ravi.id).size
  end

  test "performance shows each person's wins and money, opening their own records" do
    Forefront::Lead.create!(title: "Ravi's win", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                            source: forefront_source, status: "won", actual_amount: 2_500)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", metric(:won, member: @ravi)
    assert_equal "₹2,500.00", css_select("[data-metric='won'][data-member='#{@ravi.id}'][data-sum]").first.text.squish
    assert_equal "0", metric(:won, member: @sara)
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/per_person_test.rb`
Expected: KeyError `open_tickets`.

- [ ] **Step 3: Add the metrics**

```ruby
      # Workload per person
      define :open_tickets, title: "Open tickets", kind: :tickets do |scope, _|
        scope.tickets.unfinished
      end

      define :active_leads, title: "Open leads", kind: :leads do |scope, _|
        scope.leads.active
      end
```

- [ ] **Step 4: Add the widgets**

`_workload.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Workload" } do %>
  <table class="w-full text-sm">
    <thead><tr class="text-xs text-gray-500"><th class="text-left">Person</th><th class="text-right">Open tickets</th><th class="text-right">Open leads</th><th class="text-right">Followups today</th><th class="text-right">Overdue</th></tr></thead>
    <tbody>
      <% scope.rows.each do |person| %>
        <tr class="border-t border-gray-100"><td class="py-1"><%= person.name %></td>
          <td class="py-1 text-right"><%= metric_link :open_tickets, scope, member: person %></td>
          <td class="py-1 text-right"><%= metric_link :active_leads, scope, member: person %></td>
          <td class="py-1 text-right"><%= metric_link :followups_due_today, scope, member: person %></td>
          <td class="py-1 text-right text-red-700"><%= metric_link :overdue_followups, scope, member: person %></td></tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

`_performance.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Performance" } do %>
  <div class="overflow-x-auto">
    <table class="w-full text-sm">
      <thead><tr class="text-xs text-gray-500"><th class="text-left">Person</th>
        <% Forefront::Dashboard::Metrics::ACTIVITY.each do |key| %><th class="text-right"><%= Forefront::Dashboard::Metrics.fetch(key).title %></th><% end %>
        <th class="text-right">Won value</th><th class="text-right">Received</th></tr></thead>
      <tbody>
        <% scope.rows.each do |person| %>
          <tr class="border-t border-gray-100"><td class="py-1"><%= person.name %></td>
            <% Forefront::Dashboard::Metrics::ACTIVITY.each do |key| %><td class="py-1 text-right"><%= metric_link key, scope, member: person %></td><% end %>
            <td class="py-1 text-right"><%= metric_link :won, scope, member: person, sum: :actual_amount, money: true %></td>
            <td class="py-1 text-right"><%= metric_link :receipts_received, scope, member: person, sum: :amount, money: true %></td></tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

Add both to `_team.html.erb`. Make Performance span both columns with a wrapper `<div class="lg:col-span-2">`.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/per_person_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/per_person_test.rb
git commit -m "Show each team member's workload and performance side by side

Managers and Admins asked how each individual is performing; one row per
person, every figure opening that person's own records.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Leads by stage and Leads by source / Source ROI

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_leads_by_source.html.erb`
- Modify: `_team.html.erb`, `_company.html.erb`
- Test: `test/integration/dashboard/leads_by_test.rb`

**Interfaces:**
- Consumes: `widgets/_pipeline` with `title:` and `values: false`.
- Produces: metrics `source_leads` and `source_won` (slice: source id, periodic). The partial `_leads_by_source` takes a `title:` local.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/leads_by_test.rb
require "test_helper"

class Forefront::Dashboard::LeadsByTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(source, **attributes)
    Forefront::Lead.create!({ title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: source }.merge(attributes))
  end

  test "leads by stage on the team dashboard" do
    lead(forefront_source, status: "demo")
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", css_select(widget("leads_by_stage"), "[data-metric='pipeline'][data-slice='demo']").first.text.squish
  end

  test "leads created in the period by source, with conversion rate and revenue; the admin's is called Source ROI" do
    web = forefront_source("Website")
    lead(web)
    lead(web, status: "won", actual_amount: 4_000)
    lead(web, created_at: 60.days.ago)
    sign_in_as(@admin)

    get "/forefront/"

    roi = widget("source_roi")
    assert_equal "2", css_select(roi, "[data-metric='source_leads'][data-slice='#{web.id}']").first.text.squish
    assert_equal "1", css_select(roi, "[data-metric='source_won'][data-slice='#{web.id}']:not([data-sum])").first.text.squish
    assert_match "50%", roi.text
    assert_match "₹4,000.00", roi.text
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/leads_by_test.rb`
Expected: `widget("leads_by_stage")` is nil, or KeyError `source_leads`.

- [ ] **Step 3: Add the metrics**

```ruby
      # Leads by source / Source ROI
      define :source_leads, title: "Leads created", kind: :leads, periodic: true do |scope, source_id|
        leads = scope.leads.where(created_at: scope.period.times)
        source_id ? leads.where(source_id: source_id) : leads
      end

      define :source_won, title: "Leads created and now won", kind: :leads, periodic: true do |scope, source_id|
        fetch(:source_leads).relation(scope, source_id).won
      end
```

- [ ] **Step 4: Add the widget and place both**

`_leads_by_source.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: title } do %>
  <table class="w-full text-sm">
    <thead><tr class="text-xs text-gray-500"><th class="text-left">Source</th><th class="text-right">Leads</th><th class="text-right">Won</th><th class="text-right">Rate</th><th class="text-right">Revenue</th></tr></thead>
    <tbody>
      <% Forefront::Source.order(:name).each do |source| %>
        <% created = metric_value(:source_leads, scope, slice: source.id) %>
        <% next if created.zero? %>
        <% won = metric_value(:source_won, scope, slice: source.id) %>
        <tr class="border-t border-gray-100"><td class="py-1"><%= source.name %></td>
          <td class="py-1 text-right"><%= metric_link :source_leads, scope, slice: source.id %></td>
          <td class="py-1 text-right"><%= metric_link :source_won, scope, slice: source.id %></td>
          <td class="py-1 text-right"><%= number_to_percentage(won * 100.0 / created, precision: 0) %></td>
          <td class="py-1 text-right"><%= metric_link :source_won, scope, slice: source.id, sum: :actual_amount, money: true %></td></tr>
      <% end %>
    </tbody>
  </table>
  <p class="mt-2 text-xs text-gray-500">Leads created in the period, and how many of those are won.</p>
<% end %>
```

Changes to `_team.html.erb`:
- add `<%= render "forefront/dashboard/widgets/pipeline", scope: scope, title: "Leads by stage", values: false %>`;
- add `<%= render "forefront/dashboard/widgets/leads_by_source", scope: scope, title: (current_admin.admin? ? "Source ROI" : "Leads by source") %>`.

`_company.html.erb` gets the Source ROI through `_team`, so there's no separate render.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/leads_by_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/leads_by_test.rb
git commit -m "Show leads by stage, and which sources bring leads that convert

Managers need to see where the team's deals sit, and Admins which sources
are worth it: leads, wins, conversion rate and revenue per source.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Revenue, with a 12-month trend

**Files:**
- Create: `app/queries/forefront/dashboard/revenue_trend.rb`
- Modify: `app/queries/forefront/dashboard/metrics.rb` (`receipts_received` slices)
- Create: `app/views/forefront/dashboard/widgets/_revenue.html.erb`
- Modify: `_company.html.erb`
- Test: `test/integration/dashboard/revenue_test.rb`

**Interfaces:**
- Produces:
  - `Dashboard::RevenueTrend.new(scope, today: Date.current).months`, an Array of `[Date (month start), BigDecimal]` with 12 entries, oldest first;
  - `receipts_received` slice `one_off` or `instalment`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/revenue_test.rb
require "test_helper"

class Forefront::Dashboard::RevenueTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    lead = Forefront::Lead.create!(title: "Paying", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, status: "won", actual_amount: 30_000)
    @payment = Forefront::Payment.create!(lead: lead, total_amount: 30_000)
    @installment = @payment.installments.create!(amount: 10_000, due_on: Date.current)
  end

  def receipt(amount, on, installment: nil)
    Forefront::Receipt.create!(payment: @payment, installment: installment, amount: amount, received_on: on, payment_method: "cash", recorded_by: @rep)
  end

  test "revenue in the period is split into one-off and instalment, with a monthly trend" do
    receipt(5_000, Date.current)
    receipt(10_000, Date.current, installment: @installment)
    receipt(3_000, Date.current.prev_month)
    sign_in_as(@admin)

    get "/forefront/"

    revenue = widget("revenue")
    assert_equal "₹15,000.00", css_select(revenue, "[data-metric='receipts_received']:not([data-slice])").first.text.squish
    assert_equal "₹5,000.00", css_select(revenue, "[data-metric='receipts_received'][data-slice='one_off']").first.text.squish
    assert_equal "₹10,000.00", css_select(revenue, "[data-metric='receipts_received'][data-slice='instalment']").first.text.squish
    months = css_select(revenue, "[data-trend-month]").map { |bar| bar.text.squish }
    assert_equal 12, months.size
    assert_match "₹3,000.00", months[-2]
    assert_match "₹15,000.00", months[-1]
  end
end
```

Check `Receipt` validations. A Receipt against an installment may need to match its amount, and the total may not exceed `still_owed`. The amounts above add up to 18,000, which is within 30,000.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/revenue_test.rb`
Expected: `widget("revenue")` is nil.

- [ ] **Step 3: Implement**

Replace `receipts_received`:

```ruby
      define :receipts_received, title: "Receipts", kind: :receipts, periodic: true do |scope, kind|
        receipts = scope.receipts.where(received_on: scope.period.dates)
        case kind
        when nil then receipts
        when "one_off" then receipts.where(installment_id: nil)
        when "instalment" then receipts.where.not(installment_id: nil)
        else receipts.none
        end
      end
```

```ruby
# app/queries/forefront/dashboard/revenue_trend.rb
module Forefront
  module Dashboard
    # Receipts per month for the last 12 months (this one included), for the
    # people and Product in view. Grouped in Ruby so the SQL stays portable.
    class RevenueTrend
      def initialize(scope, today: Date.current)
        @scope = scope
        @first = today.beginning_of_month << 11
        @last = today.end_of_month
      end

      def months
        totals = @scope.receipts.where(received_on: @first..@last).pluck(:received_on, :amount)
                       .group_by { |on, _| on.beginning_of_month }.transform_values { |rows| rows.sum { |_, amount| amount } }
        (0..11).map { |offset| @first >> offset }.map { |month| [ month, totals.fetch(month, 0.to_d) ] }
      end
    end
  end
end
```

- [ ] **Step 4: Add the widget**

`_revenue.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Revenue" } do %>
  <dl class="grid grid-cols-3 gap-4 text-sm mb-4">
    <div><dt class="text-xs text-gray-500">Received · <%= scope.period.label %></dt>
      <dd class="text-xl font-semibold"><%= metric_link :receipts_received, scope, sum: :amount, money: true %><%= metric_change :receipts_received, scope, sum: :amount %></dd></div>
    <div><dt class="text-xs text-gray-500">One-off</dt><dd class="text-lg"><%= metric_link :receipts_received, scope, slice: "one_off", sum: :amount, money: true %></dd></div>
    <div><dt class="text-xs text-gray-500">Instalments</dt><dd class="text-lg"><%= metric_link :receipts_received, scope, slice: "instalment", sum: :amount, money: true %></dd></div>
  </dl>
  <p class="text-xs text-gray-500 mb-1">By product</p>
  <ul class="text-sm mb-4">
    <% scope.products.order(:name).each do |product| %>
      <li><%= product.name %>: <%= metric_link :receipts_received, scope.with(product_id: product.id), sum: :amount, money: true %></li>
    <% end %>
  </ul>
  <p class="text-xs text-gray-500 mb-1">Last 12 months</p>
  <% months = Forefront::Dashboard::RevenueTrend.new(scope).months %>
  <% top = [ months.map(&:last).max, 1 ].max %>
  <ul class="text-xs space-y-1">
    <% months.each do |month, total| %>
      <li data-trend-month="<%= month.iso8601 %>" class="flex items-center gap-2">
        <span class="w-16 text-gray-500"><%= month.strftime("%b %Y") %></span>
        <span class="h-2 bg-indigo-400 rounded" style="width: <%= (total / top * 60).round %>%"></span>
        <%= link_to format_money(total), dashboard_metric_path(:receipts_received, scope.with(period: Forefront::Dashboard::Period.for_dates(month..month.end_of_month)).to_params), class: "hover:underline" %>
      </li>
    <% end %>
  </ul>
<% end %>
```

Add it to `_company.html.erb`'s grid.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/revenue_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/revenue_test.rb
git commit -m "Show Admins revenue received, split by kind and product, over a year

The company view needs the money actually received: one-off versus
instalments, per product, and the monthly trend, each opening its receipts.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Subscriptions and Data health

**Files:**
- Modify: `app/queries/forefront/dashboard/metrics.rb`
- Create: `app/views/forefront/dashboard/widgets/_subscriptions.html.erb`, `_data_health.html.erb`
- Modify: `_company.html.erb`
- Test: `test/integration/dashboard/company_test.rb`

**Interfaces:**
- Produces: metrics `subscriptions` (slice `active`, `expiring` or `expired`; admin only) and `failed_intake` (admin only, periodic).

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/dashboard/company_test.rb
require "test_helper"

class Forefront::Dashboard::CompanyTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  def subscriber(in_days)
    customer = Forefront::Customer.create!(name: "C#{in_days}", phone: "555-#{rand(1000..9999)}")
    Forefront::Lead.create!(title: "Deal #{in_days}", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: "won", actual_amount: 1000, expires_at: in_days.days.from_now.to_date)
  end

  test "subscriptions by product: active, expiring and expired" do
    subscriber(90)
    subscriber(10)
    subscriber(-5)
    sign_in_as(@admin)

    get "/forefront/"

    subs = widget("subscriptions")
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='active']").first.text.squish
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='expiring']").first.text.squish
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='expired']").first.text.squish
  end

  test "data health counts failed signups and orphan leads" do
    Forefront::AuditEvent.record!(actor: Forefront::Admin.system_actor, action: "rejected_signup", auditable: @product, audited_changes: { "errors" => [ nil, "Phone can't be blank" ] })
    sign_in_as(@admin)

    get "/forefront/"

    health = widget("data_health")
    assert_equal "1", css_select(health, "[data-metric='failed_intake']").first.text.squish
    assert css_select(health, "[data-metric='orphan_leads']").any?
  end

  test "a manager can't open admin-only metrics" do
    sign_in_as(dashboard_staff("Mona Manager", "manager"))
    get "/forefront/dashboard/metrics/failed_intake"
    assert_redirected_to "/forefront/"
  end
end
```

Check the arguments `SignupOperations` passes to `AuditEvent.record!` for `rejected_signup`, and copy them.

- [ ] **Step 2: Run it and watch it fail**

Run: `bin/rails test test/integration/dashboard/company_test.rb`
Expected: `widget("subscriptions")` is nil.

- [ ] **Step 3: Add the metrics**

```ruby
      # Subscriptions / Data health (Company)
      define :subscriptions, title: "Subscriptions", kind: :subscriptions, roles: %w[admin] do |scope, state|
        subscriptions = scope.subscriptions
        today = Date.current
        case state
        when "active" then subscriptions.where("expires_at > ?", today + 30)
        when "expiring" then subscriptions.where(expires_at: today..(today + 30))
        when "expired" then subscriptions.where("expires_at < ?", today)
        else subscriptions.none
        end
      end

      define :failed_intake, title: "Rejected Signup API calls", kind: :audit_events, roles: %w[admin], periodic: true do |scope, _|
        events = AuditEvent.where(action: "rejected_signup", created_at: scope.period.times)
        scope.product_id ? events.where(auditable_type: Product.name, auditable_id: scope.product_id) : events
      end
```

- [ ] **Step 4: Add the widgets**

`_subscriptions.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Subscriptions" } do %>
  <table class="w-full text-sm">
    <thead><tr class="text-xs text-gray-500"><th class="text-left">Product</th><th class="text-right">Active</th><th class="text-right">Expiring (30 days)</th><th class="text-right">Expired</th></tr></thead>
    <tbody>
      <tr class="border-t border-gray-100 font-medium"><td class="py-1">All</td>
        <% %w[active expiring expired].each do |state| %><td class="py-1 text-right"><%= metric_link :subscriptions, scope, slice: state %></td><% end %></tr>
      <% unless scope.product_id %>
        <% scope.products.order(:name).each do |product| %>
          <% per_product = scope.with(product_id: product.id) %>
          <tr class="border-t border-gray-100" data-product="<%= product.id %>"><td class="py-1"><%= product.name %></td>
            <% %w[active expiring expired].each do |state| %><td class="py-1 text-right"><%= metric_link :subscriptions, per_product, slice: state %></td><% end %></tr>
        <% end %>
      <% end %>
    </tbody>
  </table>
<% end %>
```

The "All" row comes first, so `css_select(...).first` in the test reads it. The per-product rows carry the same `data-metric`/`data-slice`.

`_data_health.html.erb`:

```erb
<%= render layout: "forefront/dashboard/widget", locals: { title: "Data health" } do %>
  <dl class="grid grid-cols-2 gap-4 text-sm">
    <div><dt class="text-xs text-gray-500">Rejected Signup API calls · <%= scope.period.label %></dt><dd class="text-xl font-semibold"><%= metric_link :failed_intake, scope %></dd></div>
    <div><dt class="text-xs text-gray-500">Open leads with no followup</dt><dd class="text-xl font-semibold"><%= metric_link :orphan_leads, scope %></dd></div>
  </dl>
<% end %>
```

Add both to `_company.html.erb`'s grid.

- [ ] **Step 5: Run, lint, run the full suite, commit**

```bash
bin/rails test test/integration/dashboard/
bin/rubocop app/queries/forefront/dashboard test/integration/dashboard/company_test.rb
bin/rails test
git add app/queries/forefront/dashboard app/views/forefront/dashboard test/integration/dashboard/company_test.rb
git commit -m "Show Admins subscription health per product and data problems to fix

Which customers are active, about to lapse or already gone, plus signups the
API rejected and open leads nobody is following up.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: README and a browser check

**Files:**
- Modify: `README.md` (add a "Dashboards" section after "Alerts")

- [ ] **Step 1: Write the section**

```markdown
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
```

- [ ] **Step 2: Check it in the browser**

Start `../demo_rails_forefront` on a spare port. Sign in as an Admin, a Manager and a Sales person (temporary accounts, removed afterwards). For each one:
- open `/forefront/`, apply a period, a Product and a member filter;
- click three numbers and confirm each list matches its number;
- check the layout at 1366×768 and at 390px wide.

Note anything that looks wrong and fix it in its own commit.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Describe the role dashboards in the README

Host-app owners should know what each role sees on the home page and that
every number drills down.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
