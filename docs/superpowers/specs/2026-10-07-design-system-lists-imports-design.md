# Design system, list pages, Customer origin and Imports

Status: agreed 2026-10-07, not yet built.

## Goal

Sumit's QA list (`docs/issues.md`, items 1–14) asks for one consistent,
CRM-grade UI across every page, server-side pagination with search and
filters on every list, modal create/edit for small records, a stored
Customer origin with insights, and CSV imports. From now on every change
also brings the pages it touches up to this design system without being
asked (see AGENTS.md).

## Out of scope (parked by Sumit)

- **Item 8**: removing Renewal reward, Reclaim reward, the Expiry endpoint
  URL and token from Product. Revisit later. Nothing about it changes here.
- **Lead import**: the importer framework is built so it can be added, but
  no Lead importer, template or UI option ships now.

## Build order

Each line below is one or more small, test-first commits.

| # | Part | Issue items |
|---|------|-------------|
| 0 | Product and Campaign: unique names and an active/inactive switch | (Sumit, in chat) |
| A | Design system: ViewComponent, tokens, components, layout, docs | foundation |
| B | Every list page, and every in-page section that can exceed 20 items: server-side pagination, search, filters | 1, 2 |
| C | Modal new/edit for Sources, Lost reasons, Customers | 5, 10 |
| D | Quick views: Products on the Staff list, Staff on the Product list | 6, 7 |
| E | Product API key: shown in full once, busy state, update in place | 9 |
| F | Customer origin, Customer search and filters, Customer insights | 11, 13, 14 |
| G | Imports: Staff, Customers, Products, Sources, Lost reasons | 3, 4, 12 |

## 0. Product and Campaign: unique names and active/inactive

- New migration: `active` boolean, default true, not null, on
  `forefront_products` and `forefront_campaigns`.
- Both models `include AdminList` (case-insensitive unique `name`, `active`
  and `ordered` scopes, name squished). Campaign keeps its date and
  Source validations.
- An inactive Product drops out of the pickers for new Leads, Tickets,
  Product allocations and Targets, but stays on the records that already
  use it.
- An inactive Campaign drops out of the pickers for Leads and Tickets. A
  record can't newly pick an inactive Campaign: the validation says "is no
  longer in use", the same rule Sources already follow.
- An inactive Product's API key is refused: the Signup and Receipt APIs
  answer 403 "Product inactive". The Expiry pull keeps running for
  inactive Products, because existing Subscriptions still need renewals.
- Product and Campaign lists get an Active/Inactive filter (default
  Active) and an Activate/Deactivate row action.

## A. Design system

**Look:** "Crisp light". White surfaces on a light-grey canvas, a deep
indigo accent, compact data-dense tables, a white sidebar. It belongs to
the Pipedrive and HubSpot family, and is the smallest jump from today's
UI.

**Dependency:** `spec.add_dependency "view_component", ">= 3.0", "< 5"`.
3.x supports Rails ≥ 5.2 and 4.x supports Rails ≥ 7.1, so code uses only
the APIs both share. Tailwind stays on the CDN, as today.

**Tokens:** CSS custom properties in `forefront/application.css` (brand,
brand-soft, canvas, surface, border, text, text-muted, success, warning,
danger, info, radius, shadow). An inline `tailwind.config` in the layout
maps Tailwind colours to the variables (`bg-brand`, `text-muted`, …), so a
host re-themes by overriding a few variables.

**Components:** `app/components/forefront/ui/`, each with a test under
`test/components/`.

| Component | Purpose |
|-----------|---------|
| `PageHeaderComponent` | Title, subtitle, breadcrumb, actions slot |
| `ButtonComponent` | primary / secondary / ghost / danger, sm / md, `loading:` text shown while a Turbo submit is in flight |
| `CardComponent`, `StatCardComponent` | Panels and KPI tiles (value, label, change vs previous period) |
| `DataTableComponent` | Column definitions, rows, optional sortable headers, built-in empty state |
| `FilterBarComponent` | GET form: search box, filter slots, active-filter chips, Clear link |
| `PaginationComponent` | Wraps a Kaminari relation: "Showing 21–40 of 312" plus page links; accepts a custom `param_name` for in-page sections |
| `ModalComponent` | Frame-based modal (see below) |
| `BadgeComponent` | One colour map for Lead stages, Ticket statuses, active/inactive, import verdicts and statuses |
| `ChipListComponent` | First N items as chips, then "+N" with the full list in a `title` tooltip |
| `EmptyStateComponent` | Icon, message, optional call to action |
| `FormFieldComponent` | Label, required asterisk, hint, inline error |

**Modals:** the layout holds one empty `turbo_frame_tag "forefront_modal"`.
New and Edit links set `data-turbo-frame="forefront_modal"`. The
controller renders the form inside the frame, wrapped in `ModalComponent`.
A failed save re-renders inside the frame with a 422 status. A successful
save answers with a Turbo Stream that closes the modal, refreshes the list
and shows a flash toast; a plain HTML request just redirects. The
full-page `new` and `edit` routes keep working for non-Turbo requests.
Escape, the backdrop and a close button all dismiss the modal. Existing
`forefrontOpenModal`/`forefrontCloseModal` modals move to the new
mechanism as their pages are touched.

**Layout:** the header, a grouped sidebar with the active item highlighted,
flash toasts and the content width are all built from the same tokens.

**Docs:** `docs/design-system.md` covers the tokens, each component with a
usage snippet, and the standard list-page, form, modal and show-page
recipes. AGENTS.md gets a rule: every view uses the design system, and any
change restyles the pages it touches.

## B. Lists: server-side pagination, search and filters

- Every list is paginated in SQL with Kaminari:
  `.page(params[:page]).per(20)`. Only 20 records are loaded per request.
- In-page sections that can hold more than 20 items paginate separately
  with their own param (`leads_page`, `tickets_page`, …). These are the
  Customer page's Leads and Tickets, the Timeline, Payments and
  Installments, and the My work sections.
- Filtering and search live in `app/services/forefront/<model>_services.rb`
  as `Filter` classes, the same as the existing Lead, Ticket and Customer
  filters. Search uses `ApplicationRecord.case_insensitive_like`. Sorts
  use a whitelist.
- Every list gets an integration test that sends real query params through
  the controller. It checks that filters narrow the rows, that 21+
  records give 20 on page 1 and the rest on page 2, and that filters
  survive paging.

| List | Search | Filters |
|------|--------|---------|
| Staff | name, email | role, manager, Product allocated |
| Products | name | Staff allocated, active |
| Campaigns | name | Source, running / upcoming / ended, active |
| Sources, Lost reasons | name | active |
| Customers | see F | see F |
| Leads, Tickets | existing; verified and moved into `FilterBarComponent` | existing |
| Targets | Staff name | Product, period |
| Notifications | none | kind, read/unread |
| Audit trail | existing; verified and restyled | existing |
| Unassigned, Unattached receipts | customer name, phone | Product |
| Imports | filename | kind, status, Staff |

## C. Modals for Sources, Lost reasons, Customers

- Sources and Lost reasons lose the inline add form and the separate edit
  page. New and Edit both open in the modal.
- Customer New and Edit open in the modal from the Customers list and the
  Customer page.

## D. Quick views

- Staff list: a "Products" column showing allocated Products through
  `ChipListComponent`.
- Product list: a "Staff" column showing allocated Staff, the same way.
- Both eager-load allocations. A test guards against N+1 queries.

## E. Product API key

- The key is stored as a digest plus its last 4 characters, so it can only
  be shown at the moment it's made. That stays the case.
- Generate and Regenerate submit over Turbo. The button shows "Generating…"
  and is disabled while the request runs. The response is a Turbo Stream
  that replaces the API key panel in place, with no page refresh.
- The new panel shows the full key once, in a read-only field with a Copy
  button and the note "Copy it now; it won't be shown again". After that,
  only `••••last4` and when it was generated are shown.
- Regenerate asks for confirmation first, because the old key stops
  working immediately.

## F. Customers: origin, search and filters, insights

**Origin (item 11):**
- New migration: `source_id` and `campaign_id` (with foreign keys and
  indexes) on `forefront_customers`. No backfill, because all data is
  development data. The columns are nullable in the database, and the
  model requires `source` on create and update. `campaign` is optional
  but must belong to the chosen Source.
- The Customer form gets a Source picker (active only), then a Campaign
  picker limited to that Source's active Campaigns.
- Customers created by a Signup take the "Signup" Source. Customers created
  from a Campaign enquiry take that Campaign and its Source.
- CONTEXT.md changes from "A Customer's own origin is not stored" to
  "stored on the Customer when they first arrive, and not changed by later
  Tickets or Leads".

**Search and filters (item 13):**
- Search: name, email, phone and company in one box.
- Filters: Source, Campaign, Product (through their Leads or
  Subscriptions), Sales person (assignee of any of their Leads), status
  (prospect = no won Lead, customer = has a won Lead, open work = an open
  Lead or Ticket), date added (from–to), Import.
- Sort: newest, name, last activity.

**Insights (item 14):** `/customers/insights`, linked from the Customers
header and from the Reports index.
- The period picker is the Dashboard's (`Dashboard::Scope`).
- Stat cards: new Customers this period with the change from the previous
  period, top Source, top Campaign.
- Breakdown tables by Source and by Campaign: Customers acquired, how many
  have a won Lead and the conversion %, won revenue
  (`CurrencyHelper#format_money`), share of total with an inline bar.
- New Customers per month split by Source, drawn as a CSS/HTML stacked
  bar chart with no chart library.
- The data comes from `app/queries/forefront/customer_insights.rb`, with a
  CSV export (audited like report exports).
- Access: Admins and Managers see everyone in their scope. A Sales person
  sees only the Customers in their `policy_scope`.

## G. Imports

**Data:** a new `forefront_imports` table.
- `kind`: staff, customers, products, sources or lost_reasons.
- `created_by_id`, `filename`, `csv` (text: the uploaded file, so no
  ActiveStorage is needed).
- `status`: queued → checking → ready → importing → completed, or
  failed / cancelled.
- `rows`: a portable `json` column holding every row with its verdict
  (`create`, `duplicate` or `error`) and messages.
- Counts: total, created, skipped, failed.
- `source_id` and `campaign_id`, for customer imports.
- `started_at`, `finished_at`, timestamps.

`forefront_customers.import_id` records which import brought a Customer
in.

**Service:** `Forefront::ImportOperations`
- `create(params, by:)` validates the file (CSV, at most 5,000 rows and
  2 MB, headers match the template) and enqueues `ImportCheckJob`.
- `check(import)` dry-runs every row and stores the verdicts. Status
  becomes `ready`.
- `run(import)` re-checks each row inside its own transaction and saves
  the valid ones. It records the counts and writes an AuditEvent.
- `call(kind:, csv:, by:, **options)` does check and run synchronously,
  for console and rake use.
- Importers live in `app/operations/forefront/importers/`: `Base` (CSV
  parsing, header check, verdicts, counting) plus `Staff`, `Customers`,
  `Products`, `Sources` and `LostReasons`. Each declares its columns,
  required columns, duplicate test and `build(row)`. Lead import is left
  for later.

**Columns:** `*` = required.

| Kind | Columns | Duplicate if |
|------|---------|--------------|
| Staff | name\*, email\*, role\* (sales_person / manager / admin), password\*, manager_email, products (`;`-separated names, allocated on import) | email exists |
| Customers | name\*, email or phone\*, country_code, company, source, campaign (both override the import's choice per row) | email or phone exists |
| Products | name\*, description, active | name exists (case-insensitive) |
| Sources, Lost reasons | name\*, active | name exists (case-insensitive) |

**Flow and UI:**
1. **Imports** page (`/imports`, sidebar entry): paginated, filterable
   list of past imports.
2. **New import** modal: pick the kind, download its CSV template
   (`/imports/template.csv?kind=`), and upload a file. Customer imports
   also choose a Source (required) and a Campaign (optional).
3. Import page while `queued`/`checking`: a progress state that polls every
   2 s (a turbo-frame reload; no ActionCable needed).
4. When `ready`: counts as stat cards and a preview table (20 per page,
   filterable by verdict, with badges and messages per row), then
   **Confirm import** or **Cancel**.
5. When `completed`: the summary, links to the created records (Customers
   filtered by this import), and **Download failed rows** as a CSV in the
   template format, so it can be fixed and uploaded again.

**Access (ImportPolicy):** Admins can import any kind. Managers can import
Customers only. Sales persons can't import. Everyone sees only the imports
they're allowed to run.

**Jobs:** `ImportCheckJob` and `ImportRunJob` need the host's ActiveJob
backend; Rails' default `async` adapter is enough for development. This
is documented in the README next to `NotificationSweepJob`.

## Testing

- Component unit tests for every UI component.
- Integration tests in `test/integration/` drive each list page with real
  params, covering filters, search and both pages of pagination.
- Modal flows run through Turbo-frame requests, covering both success and
  a validation error.
- Importer unit tests per kind: valid, duplicate and invalid rows, plus
  header mismatch.
- The full import flow (upload → check → preview → confirm → summary) runs
  with `fixture_file_upload` and `perform_enqueued_jobs`.
- Customer insights query tests use a pinned clock (`travel_to`).
- The full suite runs on PostgreSQL after each commit. Each new migration
  is copied to `../demo_rails_forefront` and checked there on SQLite.
