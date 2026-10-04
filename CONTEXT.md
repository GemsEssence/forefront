# Forefront

Domain glossary for the Forefront sales/support CMS — a mountable Rails engine for managing a sales team's leads, deals, support requests, targets, and payments, usable standalone or as a plugin inside a host application.

## Language

**Customer**:
The person or organization a Lead is created for. Not an authenticatable identity — has no login and is unrelated to the Admin/Manager/Sales person staff hierarchy. When Forefront runs as a plugin, a Customer carries an optional reference back to the host application's own record, but Forefront always owns the Customer row itself; Customer is never swapped out for a host app's own model the way staff auth can be.
_Avoid_: Client, Account, User

**Staff**:
The umbrella term for anyone with a Forefront login: Admin, Manager, or Sales person.
- **Admin**: unscoped, full access — creates Managers and Sales persons, creates Products, sets targets, sees all data. An Admin oversees rather than works: they don't call Customers or carry their own Leads/Tickets (so they have no "My work"), and step in only where an approval or intervention is needed. They filter the data and run reports.
- **Manager**: scoped to their own team. Both oversees their direct reports and does sales work of their own.
- **Sales person**: scoped to their own assigned Leads/Tickets; sees their own data and does the work.
- **System**: a single non-human Staff record named "System" that acts on behalf of automated inputs (such as a Signup). It never logs in, is never given work, and never appears in leaderboards or Targets.
_Avoid_: User, Employee (for this identity)

**Lead**:
A prospect's entire journey with exactly one Product, from first contact through to a `won` or `lost` outcome. Its **stage** says how far the sale has got:
- **Open** — nobody has spoken to the Customer about it yet.
- **Contacted** — the Customer has been reached and their interest confirmed. A Lead converted from a Ticket starts here.
- **Demo** and **Proposal** — in either order, and either may be skipped.
- **Negotiation** — optional; a Customer may accept a Proposal outright.
- **Won** — the Customer has agreed to pay. Final once a Payment exists.
- **Lost** — reachable from any stage; needs a Lost reason and note, and only a Manager or Admin may reopen it.
A Lead moves freely backward and forward between Open and Negotiation. Moving into Demo or Proposal opens a Ticket for that work under the Lead (reusing one already open); opening a Ticket never moves the stage. A Lead at any stage may be **awaiting customer** — the Customer has gone quiet after a demo, a Proposal or similar. Marking it so always schedules a Followup, and changing the stage clears it; it takes the place of a "follow up" stage, so the stage never loses how far the sale had got. A white-label Lead also records when its **agreement was signed** — a milestone at any stage, never a gate on winning. Created either when a Customer first makes contact, or — for a Customer whose prior subscription has lapsed — as a fresh Lead once a cooldown period has passed (a Reclaim, see below). Reaching `won` is the sale itself: there is no separate Sale/Deal/Order record: Payments and Installments attach directly to the won Lead. A won Lead's `expires_at` is set manually by the Sales person (not derived from any Product-level term); it drives when a Renewal Ticket and, later, a Reclaim get created. A Lead carries an **estimated amount** entered when it's created, and an **actual amount** that must be entered when it's marked `won` (the deal can close for a different figure); amount-based Targets count the actual amount.
_Avoid_: Deal, Opportunity, Sale (colloquial use of "deal" to mean "a Lead" is fine in conversation, but there is no separate Deal model)

**Shared Lead**:
A Lead that has been reassigned between Sales persons at some point in its history, where everyone it was ever assigned to (its "past assignees") has agreed, outside the system, to split reward/target credit for the win among themselves — evenly by default, or at custom percentages — rather than crediting only whoever holds it at the moment it's won. One person (the current assignee, or an Admin/Manager) records the already-reached agreement in one action; Forefront doesn't implement a per-person digital approval step, so recording it is an attestation, not a request awaiting sign-off. Sharing must name every past assignee (no subset) with percentages summing to exactly 100, and it changes real numbers, not just a note: Target achievement, and a Reclaim's own reward, are computed per Sales person from their share of each Lead (100% for an unshared Lead's current assignee, their recorded percentage otherwise) rather than always crediting the win in full to one person. Everyone named in a Lead's share may open that Lead and work on it — add notes, schedule Followups, and update any Followup on it — but only the owner, the current assignee, their Managers and Admins may edit the Lead itself, change its stage, reassign it, record payments, or change the share. A participant's Leads list doesn't grow; shared Leads reach them through "Shared with me".

**Payment**:
Money owed by a Customer for the Product on a won Lead — a Lead is won the moment the Customer agrees to pay, so a Payment is never recorded before the win. Paid in full, or split into Installments; what has actually arrived is recorded as Receipts.

**Installment**:
A single scheduled portion of a Payment — amount and due date entered manually by the Sales person, not system-generated from a count/split. Each Installment drives an automated reminder Followup ahead of its due date. An Installment is paid once the Receipts against it add up to its amount.

**Receipt**:
Money actually received from a Customer against a Payment (or one of its Installments): amount, date, method and reference. May be smaller than the Installment it is against — several Receipts can together pay one Installment.

**Product**:
What's sold — created by an Admin or Manager, with a name and description but no fixed price: what a sale is worth is the won Lead's actual amount. A Sales person may only be assigned a Lead for a Product that's been allocated to them; Admins and Managers are unrestricted.
_Avoid_: Assign/Assignment for the Product-to-Sales-person link — say "allocate"/"Allocation" instead, since Assignment already means something specific (who currently owns a Ticket or Lead).

**Ticket**:
A trackable action item connected to a Customer (always), optionally to a Product, and optionally to one Lead. A Lead has many Tickets — the Ticket it was converted from, plus the Tickets for the sales work done under it (a demo, a Proposal); these share the Lead's Customer and Product. A renewal Ticket is never attached to a Lead: it names which Product's Subscription it's about, not which Lead originally sold it. Covers things like scheduling a demo, a support issue, a complaint, a feature request, or a Renewal reminder — it is not itself revenue-bearing and is independent of whether a Lead ever exists or wins. Created by any Staff member (Sales person, Manager, or Admin), or by System for a Signup; customer self-service creation, and external systems creating renewal Tickets, are both possible future phases, not current scope. A Sales person may **convert** a Ticket into a Lead once they judge the Customer ready to be asked to buy: the new Lead takes the Ticket's Customer, Product and assignee, the Ticket becomes the Lead's first Ticket, and it is resolved. When a Lead is lost, its open Tickets are closed; when it is won, they stay open.
_Avoid_: Support ticket, SupportRequest (not a separate concept — Ticket already covers this ground)

**Subscription**:
The ongoing record of a Customer's access to a Product, created automatically the moment a Lead with a Product is won and given an `expires_at`. One Subscription per won Lead; its `expires_at` is what Renewal reminders and Reclaim eligibility are computed from — it starts as a copy of the originating Lead's `expires_at` but is the one that moves when a renewal pushes the expiry out further.

**Renewal**:
A Ticket (naming a Customer and a Product, not a Lead) reminding a Sales person to ask a Customer to renew before their Subscription lapses. Resolving it records a structured `renewal_outcome` (renewed/declined) — a renewal reward is paid only on "renewed", as a percentage of the original Subscription's Payment total.

**Reclaim**:
Re-engaging a Customer whose Subscription for a given Product has already lapsed, once a cooldown period has passed (3 months post-expiry). Represented as a brand-new Lead for that Customer and Product, not a reopened old one. A reclaim reward, when the new Lead is won and paid, is a percentage of that new Lead's own Payment total.
_Avoid_: Expired lead (as a stored status — "expired" is time-based staleness derived from a Subscription's `expires_at`, not a status value stored anywhere)

**Signup**:
A Customer registering themselves in one of the Products' own applications. That application tells Forefront, which finds the Customer by phone number (or creates them) and opens a Ticket, created by System and unassigned, asking for a call to be scheduled. A Signup says nothing about how the Customer heard of the Product — that is a Campaign's job.
_Avoid_: Registration, Lead (a Signup produces a Ticket, not a Lead)

**Unassigned pool**:
The Tickets and Leads that nobody is assigned to yet. A Sales person sees the part of the pool whose Product is allocated to them and may **take** an item (assigning it to themselves); Managers and Admins see the whole pool and assign from it. Taking is recorded the same way as any other Assignment.

**Campaign**:
A marketing push that Staff run on a Source (for example an ad run on LinkedIn), with a name and a start and end date. Created by any Staff member, and not tied to any Product. When a Customer contacts the sales team after seeing it, Staff record the enquiry as a Ticket for the Product they asked about, and it is that Ticket (and any Lead converted from it) that is credited to the Campaign — not the Customer. One Customer can therefore have come from several Campaigns, one per Product they enquired about; a second enquiry about a Product they already have an open Ticket for reuses that Ticket. Distinct from a Signup: a Customer who signs up in a Product's own application is a Signup regardless of any ad they saw.

**Source**:
Where a Lead came from, or where a Campaign runs — one list, maintained by Admins (e.g. LinkedIn, Upwork, Gitex, Referral).
_Avoid_: Platform (use Source for both meanings)

**Action**:
Something Staff record against a Ticket or Lead that shows they worked on it: an Activity, a Followup scheduled or completed, a status change, or creating the Ticket/Lead itself. An assigned Ticket or Lead is **stale** when no Action has been recorded on it within a set time of its assignment, or its due date has passed with no Action since.

**Contact details**:
A Customer's email and phone. Hidden from Sales persons and Managers everywhere in Forefront until they deliberately **reveal** them, which shows them for one minute and is recorded. After a reveal they are expected to record an Action against that Customer; if they don't within a set time, Admins and Managers are alerted. Admins always see contact details. Staff may replace a Customer's contact details without revealing them — entering a new value neither counts as a reveal nor needs a follow-up Action.

**Audit event**:
A permanent record of one thing a Staff member (or System) did in Forefront — who, what, to which record, what changed, and when — including revealing contact details. Admins see all Audit events; Managers see their team's; Sales persons see none.

**Notification**:
An alert telling Staff that something needs attention — work left unassigned, stale work, a reveal with no Action, an overdue Installment. Shown in Forefront and sent by email, each one once. Admins set the time limits that decide when each kind fires.

**Proposal**:
The price and terms offered to a Customer for a Lead's Product, asked for and sent through a Ticket under that Lead. May come before or after a demo.
_Avoid_: Quotation, Quote

**Lost reason**:
Why a Lead was lost, chosen from a list Admins maintain, always accompanied by a written note — the reason alone is never enough.
