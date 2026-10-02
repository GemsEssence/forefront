# Role dashboards (part 1: on today's data)

Status: design approved in chat 2026-10-02; spec awaiting review.

## Goal

Sales persons, Managers and Admins each get a dashboard that shows what is
happening and how each person is performing. This part uses only data Forefront
already records. Widgets, or parts of widgets, that depend on features not yet
built are left out entirely, with no placeholders (see "Out of scope").

## Who sees what

| Role | Dashboard at `/` | People in scope |
|---|---|---|
| Sales person | **My Day** | themselves |
| Manager | **Team**, plus a **My Day** tab (`?tab=my_day`) for their own work | their direct reports and themselves |
| Admin | **Company** | every Manager and Sales person (`Admin.people`, role not admin) |

Admins oversee rather than work (CONTEXT.md), so they have no My Day.
"Team" means one level: a Manager's `direct_reports`.

## Filters

A filter bar sits at the top of every dashboard. It is sent as GET params, so a
filtered view can be bookmarked and shared.

- **Period** (`period`): `today`, `week`, `month` (default), `quarter`, `year`,
  or `custom` with `from`/`to` dates. Named periods are the current calendar
  unit (a week runs Monday to Sunday). Custom dates are inclusive.
- **Product** (`product_id`): Admins can pick any Product. Managers and Sales
  persons can pick only the Products allocated to them.
- **Member** (`member_id`): Managers can pick themselves or a direct report.
  Admins first pick a Manager (`manager_id`, meaning that Manager plus their
  team), then optionally a member of that team. A member outside the viewer's
  scope is ignored. Filters can't widen what a viewer is allowed to see.

**Comparison.** A number that counts or sums events in the period (wins,
demos, Receipts) also shows the change against the previous period, as
▲/▼ and a percentage. The previous period is:
- for a named period, the calendar unit before it;
- for a custom range, the same number of days immediately before it.

A number that describes the present moment (overdue now, pool size, pipeline)
has no comparison.

## Every number opens its list

Each figure is a **metric**: a key, a title, and a relation built from the
current filters. The dashboard shows `relation.count` (or a sum over it).
Clicking the number opens `/dashboard/metrics/:key` with the same filter params.
That page lists the records from the same relation, paginated, so the number
and the list always agree.

The metric registry says which roles may open which keys. The relations are
always limited to the people in scope, so the list never shows more than the
viewer could already see.

## Widgets

"Assigned to people in scope" is shortened to *in scope*. Lead stages are
the enum keys. "Active" means open to negotiation.

### My Day (a Sales person; a Manager's tab, scoped to themselves)

| Widget | Metric definitions |
|---|---|
| Action strip | **Overdue Followups**: pending, assigned in scope, `scheduled_for` before now. **Due today**: pending, scheduled later today. **Newly assigned**: Assignments to people in scope created in the period (comparison). |
| Target meter | Each Target in scope whose own period includes today, filtered by Product: `achieved_value` (own and shared credit, `Target#achieved_value`) against `goal_value`, and the **daily run rate needed**, i.e. what's left of the goal ÷ days left including today. The period filter doesn't apply, because a Target has its own period. |
| My pipeline | Active Leads in scope grouped by stage: count and summed `estimated_amount`. Leads with a LeadShare carry a "shared" mark. |
| Shared with me | Leads with a LeadShare where the viewer is a participant but not the assignee: title, the viewer's percentage, and the next pending Followup. |
| Payments due | **Awaiting payment**: won Leads in scope with no Payment, or a `pending` Payment. **Instalments due**: pending, `due_on` from today to 7 days ahead. **Instalments overdue**: pending, `due_on` before today. |
| Renewal Tickets | Unfinished `plan_expired` Tickets in scope, with days until the Customer's Subscription to that Product expires. A negative number means it has already lapsed. |
| Orphan | Active Leads in scope with no pending Followup. |
| My activity | All of these come with a comparison. **Demos**: StatusHistory into Demo on a Lead, `changed_by` in scope, in the period. **Proposals**: the same, into Proposal. **Conversions**: AuditEvents `converted` on a Ticket, actor in scope, in the period. **Won**: Leads in scope with `won_at` in the period. **Lost**: StatusHistory into Lost in the period, on Leads in scope. |

### Team (Manager)

| Widget | Metric definitions |
|---|---|
| Unassigned pool | Uses `UnassignedPool.visible_to(viewer)`, Tickets and Leads. Counts by Product, by Source (Leads only), and by age: under 2 hours, 2–24 hours, 1–3 days, over 3 days. The 5 oldest are listed with an Assign button. |
| Workload per person | One row per person in scope: open Tickets, active Leads, Followups due today, overdue Followups. |
| Leads by stage | Active Leads in scope by stage (count). Respects the member and Product filters. |
| Leads by source | Leads in scope **created in the period**, grouped by Source: count, how many of them are now won, the conversion rate, and revenue (summed `actual_amount` of those won). |
| Team target | Current Targets in scope, totalled separately for amount and lead-count Targets, plus a progress bar per person. |
| Payments | **Received today** and **received in the period** (comparison): sums of Receipts by `received_on`, on Leads in scope. **Overdue instalments**: as on My Day. |
| Renewal risk | Subscriptions on Leads in scope expiring within 30 days, where the Customer has no `plan_expired` Ticket for that Product, or has one with no Action recorded on it yet. |
| Performance per person | One row per person: the My activity numbers, plus won value (`actual_amount`) and Receipts received in the period. Each cell opens its list. |

### Company (Admin)

Every Team widget runs across all teams and Products, narrowed by the filters.
On this dashboard **Leads by source** is titled **Source ROI**; it is the same
widget. In addition:

| Widget | Metric definitions |
|---|---|
| Revenue | Receipts with `received_on` in the period (comparison), split into **one-off** (no Installment) and **instalment** (against an Installment), and by Product. A **12-month trend** shows monthly totals ending this month, built from one query plus grouping in Ruby, so the SQL stays portable. |
| Subscriptions | By Product: **active** (expires more than 30 days out), **expiring** (0–30 days), **expired**. |
| Data health | **Failed intake**: AuditEvents `rejected_signup` in the period. **Orphan leads**: active Leads with no pending Followup. |

## Out of scope (until their features exist)

- SLA ("at risk", first response, breaches)
- private Leads and counts-only display
- Calls and connected Calls; maximum attempts / not responding
- free plans and trials
- the Requests inbox
- voids and refunds
- renewal and upgrade revenue
- grace periods and churn
- duplicates to merge
- unowned Subscriptions from an expiry API

## Code layout

- `app/queries/forefront/dashboard/period.rb`: parses the period params; returns the range and the previous range.
- `app/queries/forefront/dashboard/scope.rb`:
  - holds the viewer, period, Product and member/Manager filters;
  - works out the people in scope (always within what the viewer can see);
  - provides `previous`, the same scope over the previous period.
- `app/queries/forefront/dashboard/metrics.rb`: the registry. Each key maps to a title, the roles allowed to open it, the record type, and a lambda from scope to relation.
- `app/queries/forefront/dashboard/my_day.rb`, `team.rb`, `company.rb`: assemble each widget's numbers from the metrics.
- `DashboardController#index` picks the dashboard by role, and the tab for Managers.
- `DashboardMetricsController#show` renders a drill-down list. It is authorized through `DashboardPolicy`: the role must be allowed that metric.
- Views: `dashboard/_filters`, one partial per dashboard, one partial per widget, and `dashboard_metrics/show` with one row partial per record type.
- `DashboardSummary`, the old leaderboard and the old tiles are removed, including the unscoped Ticket/Lead/Customer count tiles that showed company-wide totals to Sales persons.

## Testing

- Integration tests through `GET /` and `GET /dashboard/metrics/:key`, signed in as each role. Each widget's numbers are checked against seeded records, and the drill-down list is checked to contain exactly the records behind the number.
- Scoping tests:
  - a Sales person never sees another person's records;
  - a Manager sees only their team and themselves;
  - a `member_id` outside the viewer's scope is ignored;
  - a role can't open a metric that isn't its own.
- Period tests: each named period, custom ranges, and the previous-period comparison.
- `test/integration/dashboard_test.rb` and `test/queries/forefront/dashboard_summary_test.rb` are replaced.

## Build order (one commit each, suite green between)

1. Period, Scope and the filter bar. `/` picks the dashboard by role. The old tiles and summary are removed.
2. The metric registry and the drill-down page.
3. Action strip.
4. My pipeline and Orphan.
5. Target meter and Team target.
6. Shared with me.
7. Payments due and Payments.
8. Renewal Tickets and Renewal risk.
9. My activity, with comparison.
10. Unassigned pool.
11. Workload per person and Performance per person.
12. Leads by stage and Leads by source / Source ROI.
13. Revenue, with the trend.
14. Subscriptions and Data health.
15. README section on dashboards.
