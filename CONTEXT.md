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
A Lead that has been reassigned between Sales persons at some point in its history, where everyone it was ever assigned to has unanimously agreed to split reward/target credit for the win among themselves — evenly by default, or at custom percentages they agree on — rather than crediting only whoever holds it at the moment it's won.

**Payment**:
Money owed by a Customer for the Product on a won Lead. Paid in full, or split into Installments.

**Installment**:
A single scheduled portion of a Payment — amount and due date entered manually by the Sales person, not system-generated from a count/split. Each Installment drives an automated reminder Followup ahead of its due date.

**Product**:
What's sold — created by an Admin or Manager, with a name and a price. A Sales person may only be assigned a Lead for a Product that's been allocated to them; Admins and Managers are unrestricted.
_Avoid_: Assign/Assignment for the Product-to-Sales-person link — say "allocate"/"Allocation" instead, since Assignment already means something specific (who currently owns a Ticket or Lead).

**Ticket**:
A trackable action item connected to a Customer (always) and optionally to a Lead. Covers things like scheduling a demo, a support issue, a complaint, a feature request, or a Renewal reminder — it is not itself revenue-bearing and is independent of whether a Lead ever exists or wins. Created by any Staff member (Sales person, Manager, or Admin); customer self-service creation is a possible future phase, not current scope.
_Avoid_: Support ticket, SupportRequest (not a separate concept — Ticket already covers this ground)

**Renewal**:
A Ticket (not a Lead) reminding a Sales person to ask a Customer to renew their subscription before it lapses.

**Reclaim**:
Re-engaging a Customer whose subscription has already lapsed, once a cooldown period has passed (e.g. 3 months post-expiry). Represented as a brand-new Lead for that Customer, not a reopened old one.
_Avoid_: Expired lead (as a stored status — "expired" is time-based staleness derived from dates, not a status value stored anywhere)
