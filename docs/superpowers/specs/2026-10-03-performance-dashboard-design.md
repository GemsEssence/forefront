# Performance dashboard (on today's data)

Status: design approved in chat 2026-10-03; spec awaiting review.

## Goal

Managers and Admins see how each person is performing over a period: one
sortable row per person (or per Manager's team, for Admins), with a
month-by-month trend for one person, for one-to-one reviews. A Sales person
sees the same numbers for themselves only. Every number opens the records
behind it.

This part uses only data Forefront already records. Metrics that depend on
features not yet built are left out entirely (see "Out of scope").

## Who sees what

| Role | `/performance` shows |
|---|---|
| Sales person | **My performance**: their own row and their own 12-month trend. No other people, no ranking. |
| Manager | One row per person: their direct reports and themselves, sortable. |
| Admin | One row per Manager's team (team totals, the Manager's own work included), plus a **No manager** row for Sales persons without one. Clicking a team opens the same page with `manager_id` set, showing one row per person in it. |

A sidebar link appears in the Team group for Managers and Admins, and as
"My performance" for Sales persons. Visibility follows the role dashboards:
filters only ever narrow what a viewer may see.

## Filters

The same filter bar as the role dashboards: period (with Custom dates),
Product, and person (Manager) or Manager then person (Admin). This reuses
`Dashboard::Period` and `Dashboard::Scope`. Targets ignore the period
filter, because a Target has its own period.

## Sorting

Each column header links to the same page with `sort=<metric>&dir=asc|desc`.
The default is Revenue collected, descending. Sorting happens in Ruby over the
rows already computed (at most one row per person or team). An unknown `sort`
falls back to the default.

## Metrics

"The person" means the row's people: one person, or everyone in a team row.
*In the period* means the timestamp falls within the period filter. For a
rate, team rows add up numerators and denominators before dividing. A rate
with a zero denominator shows "—".

| Metric | Definition | Opens |
|---|---|---|
| **Records claimed** | Assignments with no previous assignee (`from_user_id` nil), made by the person to themselves (`changed_by_id = to_user_id`), in the period, on a Ticket or Lead **not created by that person**. Records someone created themselves are never claims. | those Assignments |
| **Avg time to claim** | For the claims above: the mean time from the record's `created_at` (it entered the pool) to the Assignment's `created_at`, shown in hours (one decimal place). | the claims |
| **Ticket → lead rate** | Numerator: Enquiry and Signup Tickets assigned to the person that were converted to a Lead in the period (an AuditEvent `converted` on the Ticket, `created_at` in the period). Denominator: the numerator, plus Enquiry and Signup Tickets assigned to the person that moved to Resolved or Closed in the period (a StatusHistory into Resolved or Closed) without being converted. Shown as "x of y (z%)". | numerator and denominator lists separately |
| **Lead → win rate** | Leads assigned to the person that closed in the period. Won is `won_at` in the period. Lost is a StatusHistory into Lost in the period. The rate is Won ÷ (Won + Lost). | won list, lost list |
| **Demos done** | StatusHistory into Demo on a Lead, `changed_by` the person, in the period. This is the same as the dashboard's `demos` metric. | those stage moves |
| **Revenue collected** | For each Receipt with `received_on` in the period, its amount × the person's share of that Receipt's Lead (`Lead#share_fraction_for`: the LeadShare percentage, or 100% for the assignee of an unshared Lead). The sum over the person's Leads. | the Receipts counted |
| **Shared revenue** | The part of Revenue collected that came from Leads with a LeadShare. | those Receipts |
| **Target achievement %** | The existing Target rule for the person's Targets running today: Σ `achieved_value` ÷ Σ `goal_value`, computed separately for amount and lead-count Targets. Shown as amount %, and lead-count % if any. | the won Leads credited to those Targets (`Target#credited_leads`, combined) |
| **Collected vs target %** | Revenue collected ÷ Σ `goal_value` of the person's amount-based Targets running today. Shown only when they have one. This sits alongside Target achievement, which still counts won amounts (agreed option C). | the Receipts counted |
| **Avg deal size** | Σ `actual_amount` ÷ number of Leads won in the period (`won_at` in the period), assigned to the person. | the won Leads |
| **Avg sales cycle** | The mean of (`won_at` − `created_at`) in days, one decimal place, for the same won Leads. | the won Leads |
| **Follow-up discipline** | Denominator: Followups assigned to the person with `scheduled_for` in the period, excluding cancelled ones. Numerator: those completed (`completed_at` present) by the end of their scheduled day. | numerator and denominator lists |
| **Overdue now** | Pending Followups assigned to the person with `scheduled_for` before now. Not period-bound. This is the same as the dashboard's `overdue_followups`. | those Followups |
| **Instalment collection** | Denominator: Instalments on the person's Leads with `due_on` in the period. Numerator: those paid (`paid_at` present) on or before `due_on`. | numerator and denominator lists |
| **Renewal rate** | Renewal (`plan_expired`) Tickets assigned to the person that are Resolved or Closed in the period with a `renewal_outcome`. Renewed ÷ all of those. | renewed list, all list |
| **Lost by reason** | The top 3 Lost reasons, with counts, among the person's Leads lost in the period. The full breakdown opens on click. | the lost Leads, by reason |

## Trend

`/performance/:admin_id/trend` shows the 12 months ending with this one, one
column per month, one row per metric above. Overdue now and Target
achievement are left out, because they describe today and not a month. Each
month is computed as that month's custom period. A Sales person can open
only their own trend. A Manager can open their reports' and their own. An
Admin can open anyone's. Any other person returns 404.

## Out of scope (until their features exist)

- Avg first response time (needs logged call attempts and working hours)
- Calls logged and connected (needs Call logging)
- Demo no-shows (needs a demo outcome)
- Released records with reasons (needs releasing work back to the pool)

## Code layout

- `app/queries/forefront/performance.rb`: `Performance.new(scope)` with `rows` (person or team rows, each a Struct of metric values with numerators and denominators) and `trend(person)`. It uses `Dashboard::Scope` and its relations. Durations are computed in Ruby from plucked timestamps, so the SQL stays portable.
- New metrics are added to `Dashboard::Metrics` for every list a number opens: `claims`, `enquiries_finished`, `enquiries_converted`, `leads_lost`, `followups_due`, `followups_on_time`, `instalments_due`, `instalments_on_time`, `renewals_closed`, `renewals_renewed`, `receipts_credited`, `receipts_shared`, `target_credited`. Existing metrics are reused where they match: `demos`, `won`, `overdue_followups`.
- `PerformanceController#index` and `#trend`. Pundit: a new `PerformancePolicy` (`index?` for every role; `trend?` when the person is the viewer, or within the viewer's visible people).
- Views: `performance/index` (the ranking table) and `performance/trend`, plus a sidebar entry.

## Testing

- Integration tests through `GET /forefront/performance`, signed in as each role:
  - a Sales person sees only themselves and has no ranking;
  - a Manager sees their team plus themselves;
  - an Admin sees one row per team plus "No manager", and the team click-through.
- One test per metric, with seeded records, checking both the value and that the list it opens contains exactly the records behind it. This includes:
  - the claim rule (a record you created yourself is not a claim);
  - shared credit;
  - team aggregation of rates;
  - a zero denominator shown as "—".
- Sorting: by a column, both directions, and the fallback for an unknown key.
- Trend: 12 months, the right month buckets, and 404 for a person outside the viewer's scope.
- A query-count test: growth per extra person stays bounded, as on the Company dashboard.

## Build order (one commit each, suite green between)

1. The page, the policy, the sidebar entry, and role visibility (rows only).
2. Records claimed and Avg time to claim.
3. Ticket → lead rate and Lead → win rate.
4. Demos done, Avg deal size, and Avg sales cycle.
5. Revenue collected and Shared revenue.
6. Target achievement % and Collected vs target %.
7. Follow-up discipline and Overdue now.
8. Instalment collection and Renewal rate.
9. Lost by reason.
10. Sorting.
11. Admin team rows and the "No manager" row.
12. The trend page.
13. The query-count test and the README section.
