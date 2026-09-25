# Forefront

Domain glossary for the Forefront sales/support CMS — a mountable Rails engine for managing a sales team's leads, deals, support requests, targets, and payments, usable standalone or as a plugin inside a host application.

## Language

**Customer**:
The person or organization a Lead is created for. Not an authenticatable identity — has no login and is unrelated to the Admin/Manager/Sales person staff hierarchy. When Forefront runs as a plugin, a Customer carries an optional reference back to the host application's own record, but Forefront always owns the Customer row itself; Customer is never swapped out for a host app's own model the way staff auth can be.
_Avoid_: Client, Account, User

**Staff**:
The umbrella term for anyone with a Forefront login: Admin, Manager, or Sales person.
- **Admin**: unscoped, full access — creates Managers and Sales persons, creates Products, sets targets, sees all data.
- **Manager**: scoped to their own team.
- **Sales person**: scoped to their own assigned Leads/Tickets.
_Avoid_: User, Employee (for this identity)

**Lead**:
A prospect's entire journey with exactly one Product, from first contact through to a `won` or `lost` outcome (passing through proposal/negotiation stages along the way). Created either when a Customer first makes contact, or — for a Customer whose prior subscription has lapsed — as a fresh Lead once a cooldown period has passed (a Reclaim, see below). Reaching `won` is the sale itself: there is no separate Sale/Deal/Order record: Payments and Installments attach directly to the won Lead. A won Lead's `expires_at` is set manually by the Sales person (not derived from any Product-level term); it drives when a Renewal Ticket and, later, a Reclaim get created.
_Avoid_: Deal, Opportunity, Sale (colloquial use of "deal" to mean "a Lead" is fine in conversation, but there is no separate Deal model)

**Shared Lead**:
A Lead that has been reassigned between Sales persons at some point in its history, where everyone it was ever assigned to (its "past assignees") has agreed, outside the system, to split reward/target credit for the win among themselves — evenly by default, or at custom percentages — rather than crediting only whoever holds it at the moment it's won. One person (the current assignee, or an Admin/Manager) records the already-reached agreement in one action; Forefront doesn't implement a per-person digital approval step, so recording it is an attestation, not a request awaiting sign-off. Sharing must name every past assignee (no subset) with percentages summing to exactly 100, and it changes real numbers, not just a note: Target achievement, and a Reclaim's own reward, are computed per Sales person from their share of each Lead (100% for an unshared Lead's current assignee, their recorded percentage otherwise) rather than always crediting the win in full to one person.

**Payment**:
Money owed by a Customer for the Product on a won Lead. Paid in full, or split into Installments.

**Installment**:
A single scheduled portion of a Payment — amount and due date entered manually by the Sales person, not system-generated from a count/split. Each Installment drives an automated reminder Followup ahead of its due date.

**Product**:
What's sold — created by an Admin or Manager, with a name and description but no fixed price: what a sale is worth is the won Lead's Payment total, which is also what amount-based Targets count. A Sales person may only be assigned a Lead for a Product that's been allocated to them; Admins and Managers are unrestricted.
_Avoid_: Assign/Assignment for the Product-to-Sales-person link — say "allocate"/"Allocation" instead, since Assignment already means something specific (who currently owns a Ticket or Lead).

**Ticket**:
A trackable action item connected to a Customer (always) and optionally to a Product (never directly to a Lead — a renewal Ticket names which Product's Subscription it's about, not which Lead originally sold it). Covers things like scheduling a demo, a support issue, a complaint, a feature request, or a Renewal reminder — it is not itself revenue-bearing and is independent of whether a Lead ever exists or wins. Created by any Staff member (Sales person, Manager, or Admin); customer self-service creation, and external systems creating renewal Tickets via an API once Forefront supports being used as a plugin, are both possible future phases, not current scope.
_Avoid_: Support ticket, SupportRequest (not a separate concept — Ticket already covers this ground)

**Subscription**:
The ongoing record of a Customer's access to a Product, created automatically the moment a Lead with a Product is won and given an `expires_at`. One Subscription per won Lead; its `expires_at` is what Renewal reminders and Reclaim eligibility are computed from — it starts as a copy of the originating Lead's `expires_at` but is the one that moves when a renewal pushes the expiry out further.

**Renewal**:
A Ticket (naming a Customer and a Product, not a Lead) reminding a Sales person to ask a Customer to renew before their Subscription lapses. Resolving it records a structured `renewal_outcome` (renewed/declined) — a renewal reward is paid only on "renewed", as a percentage of the original Subscription's Payment total.

**Reclaim**:
Re-engaging a Customer whose Subscription for a given Product has already lapsed, once a cooldown period has passed (3 months post-expiry). Represented as a brand-new Lead for that Customer and Product, not a reopened old one. A reclaim reward, when the new Lead is won and paid, is a percentage of that new Lead's own Payment total.
_Avoid_: Expired lead (as a stored status — "expired" is time-based staleness derived from a Subscription's `expires_at`, not a status value stored anywhere)
