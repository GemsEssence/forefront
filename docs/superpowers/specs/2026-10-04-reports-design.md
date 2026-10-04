# Reports (on today's data)

Status: design approved in chat 2026-10-04; spec awaiting review.

## Goal

Dashboards answer "what should I do now". Reports answer "what happened": a
table for a chosen period, filtered and exportable. This part builds a
shared report framework and the 17 reports that Forefront's current data
supports. Reports that need features not yet built are left out entirely
(see "Out of scope").

## Pages and access

- `/forefront/reports` lists the reports the viewer may open, grouped as
  Pipeline, Activity, Money and Admin. It is linked from a **Reports**
  sidebar entry for every role.
- `/forefront/reports/:key` shows one report: the filter bar, the table, and
  an **Export CSV** button. The CSV is the same table, using the same
  filters (`/forefront/reports/:key.csv`).
- Each report declares the roles that may open it. Any other role gets the
  usual "not authorized" redirect.
- **"All (scoped)"** means every role may open the report, and the rows are
  limited to the people the viewer may see. This uses the dashboards'
  `Dashboard::Scope`: a Sales person sees themselves, a Manager their team
  and themselves, an Admin everyone.
- **Export:** anyone who can see a report can export it (agreed option A).
  Each export records an AuditEvent `exported_report`. Its `audited_changes`
  hold the report key and the filters, and the actor is the viewer.

## Filters

Every report:
- **Period:** the dashboards' period (Today, This week, This month, This
  quarter, This year, Custom dates).
- **Product.**
- **Manager / team** (Admins; "No manager" included).
- **Sales person.**

All of these come from `Dashboard::Scope.from_params`, so they never widen
visibility.

Reports that say so also take:
- **Source** (`source_id`): applies to Leads.
- **Campaign** (`campaign_id`): applies to Leads and Tickets.

Each is ignored unless it names an existing record.

**Break down by** (`breakdown` = none | day | week | month | quarter) is
offered only on Lead source, Revenue, Follow-up and Ticket.
- When set, each numeric column becomes one column per bucket within the
  period, plus a Total column.
- Buckets are calendar units, and weeks run Monday to Sunday.
- Grouping happens in Ruby from plucked dates, so the SQL stays portable.
- Unknown values mean none.

## Building blocks

- `app/queries/forefront/reports/base.rb`: `Reports::Base`. A subclass
  declares:
  - `key`, `title`, `group` (pipeline / activity / money / admin), and
    `roles` (default all three);
  - `filters` (`[:source, :campaign]`, or a subset);
  - `breakdown?`;
  - `columns`, an Array of `{ key:, title:, format: }` where format is one of
    `:count :money :percent :days :hours :text :date`;
  - `rows(context)`, which returns Arrays of values in column order.
- `context` wraps a `Dashboard::Scope` plus the optional `source_id`,
  `campaign_id` and `breakdown`.
- `app/queries/forefront/reports.rb`: the registry. `Reports.all`,
  `Reports.fetch(key)`, and `Reports.visible_to(admin)`. Defining a key
  twice raises an error.
- `ReportsController#index`, `#show` (HTML and CSV), and
  `Forefront::ReportPolicy` (`index?` for everyone; `show?` when the
  viewer's role is in the report's roles).
- `app/queries/forefront/report_csv.rb`: writes a report's columns and rows
  as CSV, with the same values as the table. Money is a plain number with
  two decimals, and percentages are numbers.
- Views: `reports/index`, plus one shared `reports/show` that renders any
  report's columns and rows.

## The reports

"In scope" means the people in the Scope (by assignee unless stated). "In
the period" means the record's stated timestamp falls within the period. A
rate with a zero denominator shows "—".

### Pipeline

| Report (key) | Who | Filters | Rows | Columns |
|---|---|---|---|---|
| **Lead source** (`lead_source`) | Manager, Admin | Source, Campaign; breakdown | One per (Source, Campaign) pair among the Leads created in the period; Leads with no Campaign form the Source's "—" row | Leads created in the period · won (of those) · conversion % · revenue (Σ `actual_amount` of those won) · avg days from created to won (of those won) |
| **Lead stage** (`lead_stage`) | All (scoped) | Source, Campaign | One per active stage (open, contacted, demo, proposal, negotiation) | Open Leads now · expected value (Σ `estimated_amount`) · avg days in the current stage. The stage start is the latest StatusHistory into that stage, or the Lead's `created_at` if there is none. Point-in-time, so the period doesn't apply. |
| **Pipeline and forecast** (`pipeline_forecast`) | Manager, Admin | Source, Campaign | One per month of `due_at` (active Leads; the earliest row lumps all past-due Leads together as "Overdue"; Leads with no due date form a "No date" row) | One count and one expected-value column per active stage, plus a Total. Point-in-time. |
| **Conversion funnel** (`conversion_funnel`) | Manager, Admin | Source, Campaign | One per step: Enquiry/Signup Tickets created in the period → Leads converted from them → reached Contacted → reached Demo → reached Proposal → Won → Paid in full | Count · % of the previous step · % of the first step. Each step after "Leads converted" follows the same Leads. "Reached" means the Lead is at that stage or past it, or has a StatusHistory into it. Paid in full means the Lead has a Payment that is `fully_paid?`. |
| **Lost analysis** (`lost_analysis`) | Manager, Admin | Source, Campaign | One per Lost reason (the last row is "No reason" if any) | Leads lost in the period (a StatusHistory into Lost) · value lost (Σ `estimated_amount`) · most common stage at loss (the `old_status` of that StatusHistory) · top person · top Source |

### Activity

| Report (key) | Who | Filters | Rows | Columns |
|---|---|---|---|---|
| **Follow-up** (`followups`) | All (scoped) | breakdown | One per person in scope | Due: `scheduled_for` in the period and at or before now, excluding cancelled. Done on time: completed by the end of the scheduled day. Done late: completed after it. Overdue now: pending and past. Rescheduled: Followups due in the period that have an `updated_followup` AuditEvent whose changes include `scheduled_for`. |
| **Ticket** (`tickets`) | Manager, Admin | Campaign; breakdown | One per Ticket category | Opened in the period · resolved or closed in the period (a StatusHistory into Resolved or Closed) · avg hours to resolve (from created to that StatusHistory) · Tickets with a Lead ÷ distinct Leads (Tickets per Lead) |
| **Workload** (`workload`) | Manager, Admin | — | One per person in scope | Open Tickets · open Leads · Followups due today · Followups overdue. Point-in-time. |
| **Pool** (`pool`) | Manager, Admin | Campaign | One per person who claimed, plus a summary row | Summary row: records that entered the pool in the period (Tickets and Leads created with no assignee) · still unclaimed now. Per person: claims in the period (the Performance `claims` rule) · avg hours to claim. |
| **Number reveal** (`number_reveals`) | Admin | — | One per person who revealed | Reveals in the period · distinct Customers · reveals with no Action afterwards (`ContactReveal#answered?` false) |

### Money

| Report (key) | Who | Filters | Rows | Columns |
|---|---|---|---|---|
| **Revenue** (`revenue`) | Manager, Admin | Source, Campaign; breakdown | One per Product (plus "No product") | Receipts received in the period: one-off · instalment · total. These are on Leads in scope, counted in full (not by share). |
| **Instalment** (`instalments`) | All (scoped) | — | One per Lead with Instalments due in the period | Lead · Customer · person · scheduled (Σ due in the period) · paid on time · paid late · overdue (pending and past due) · balance outstanding on the Lead (Σ pending Instalments minus their receipts) |
| **Shared lead** (`shared_leads`) | All (scoped) | — | One per shared Lead where anyone in scope takes part | Lead · Customer · participants with percentages (as text) · receipts in the period · credited to each in-scope participant (as text: "Ravi ₹600 · Pia ₹400") |
| **Target vs achievement** (`targets`) | All (scoped) | — | One per Target whose own period overlaps the chosen period, for people in scope | Person · Product · Target period · metric · goal · achieved (`Target#achieved_value`) · gap · % |
| **Subscription** (`subscriptions`) | All (scoped) | — | One per Product | Active (expires more than 60 days out) · expiring in 0–7 days · 8–30 days · 31–60 days · expired. This counts Subscriptions on Leads in scope, point-in-time. |

### Admin

| Report (key) | Who | Filters | Rows | Columns |
|---|---|---|---|---|
| **Audit report** (`audit`) | Admin | — | One per AuditEvent in the period with action in `revealed_contact`, `exported_report`, `recorded_lead_share`, `updated_settings`, `assigned` | When · who · action · record · changes (as text) |
| **Data quality** (`data_quality`) | Admin | — | One per check | Check · count. The checks are: active Leads with no pending Followup; rejected Signup API calls in the period; Customers with no email; Leads with no Product; won Leads with no Payment. |

## Out of scope (until their features exist)

- Not-responding report
- Call activity report
- SLA report
- Payment register (voids, bounced, attached and unattached payments)
- Renewal and churn
- Free plan conversion
- Reward statement approvals
- Referrals
- The Plan and City filters
- True `.xlsx` export (CSV for now, option A)

## Testing

- Integration tests per report through `GET /forefront/reports/:key`:
  - rows checked against seeded records;
  - the Source, Campaign and period filters;
  - breakdown buckets on the four reports that have them;
  - role access (a disallowed role is redirected);
  - "scoped" reports never showing another team's records.
- A CSV test per batch: the CSV equals the table's columns and rows.
- An export test: an `exported_report` AuditEvent is recorded with the key
  and the filters.
- A registry test: a duplicate key raises.

## Build order (one commit each, suite green between)

1. The framework: registry, Base, controller, policy, index and show
   pages, CSV export with audit, and the sidebar link. Lead stage is the
   first report.
2. Lead source (with breakdown).
3. Pipeline and forecast.
4. Conversion funnel.
5. Lost analysis.
6. Follow-up (with breakdown).
7. Ticket (with breakdown).
8. Workload and Pool.
9. Number reveal.
10. Revenue (with breakdown).
11. Instalment and Shared lead.
12. Target vs achievement and Subscription.
13. Audit report and Data quality.
14. README section.
