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
Only the Lead's **assignee** works it: moves its stage, schedules and completes Followups, adds notes, records payments. A Sales person moves it through stage actions (customer reached, schedule demo, send proposal, customer went quiet, won, lost); a Manager may also move it to any stage to correct it, reassign it, reopen it or record a share, and may leave a note; an Admin creates, assigns and reads, never works. Moving into Demo or Proposal opens a Ticket for that work under the Lead (reusing one already open); opening a Ticket never moves the stage. An active Lead always has a Next step (see below) and a Deadline (see below). A Lead at any stage may be **awaiting customer** — the Customer has gone quiet after a demo, a Proposal or similar. Marking it so always schedules a Followup, and changing the stage clears it; it takes the place of a "follow up" stage, so the stage never loses how far the sale had got. A white-label Lead also records when its **agreement was signed** — a milestone at any stage, never a gate on winning. A Customer has at most one **unfinished** Lead (neither Won nor Lost) per Product at a time: a second one is never created, and a Lost Lead is reopened rather than duplicated. Created either when a Customer first makes contact, or — for a Customer whose prior subscription has lapsed — as a fresh Lead once a cooldown period has passed (a Reclaim, see below), which may sit beside the earlier Won Lead. Reopening a Lost Lead returns it to Open, and the Manager or Admin reopening it chooses its assignee or sends it to the pool. A Lead created by hand in the Lead form is a Private Lead (see below) until Won, Lost or shared; a Lead converted from a Ticket never is. Reaching `won` is the sale itself: there is no separate Sale/Deal/Order record: Payments and Installments attach directly to the won Lead. A won Lead's `expires_at` is set manually by the Sales person (not derived from any Product-level term); it drives when a Renewal Ticket and, later, a Reclaim get created. A Lead carries an **estimated amount** entered when it's created, and an **actual amount** that must be entered when it's marked `won` (the deal can close for a different figure); amount-based Targets count the actual amount.
_Avoid_: Deal, Opportunity, Sale (colloquial use of "deal" to mean "a Lead" is fine in conversation, but there is no separate Deal model)

**Shared Lead**:
A Lead whose reward/target credit for the win is split among several Staff at agreed percentages, rather than credited only to whoever holds it when it's won. The split is recorded in one action by the owner, the current assignee, their Managers or an Admin, as an attestation of an agreement already reached outside the system — there is no per-person acceptance step. A share names the current assignee plus any Sales person allocated the Lead's Product or any Manager (never an Admin or System; past assignees may be named but need not be), with percentages summing to exactly 100. It changes real numbers, not just a note: Target achievement, and a Reclaim's own reward, are computed per Sales person from their share of each Lead (100% for an unshared Lead's current assignee, their recorded percentage otherwise). Everyone named in a Lead's share may open that Lead and work on it — add notes, schedule Followups, and update any Followup on it — but only the owner, the current assignee, their Managers and Admins may edit the Lead itself, change its stage, reassign it, record payments, or change the share. Sharing a Private Lead ends its privacy. A participant's Leads list doesn't grow; shared Leads reach them through "Shared with me".
_Avoid_: Invitation, Accept (sharing is recorded, never proposed)

**Private Lead**:
A Lead created by hand in the Lead form, hidden from the owner's Manager — their lists, dashboards, Targets, reports and alerts — until it is Won, Lost or shared, or the owner unticks privacy. Admins always see it. A Private Lead is always assigned (it is never in the pool) and can only change hands by being shared. An Admin never creates one: a Lead an Admin hands to someone is visible to that person's Manager. Stale-work and reveal alerts about it go to the owner alone while it is private.
_Avoid_: Hidden lead, Personal lead

**Followup**:
A dated, typed (call, email, meeting, demo) reminder on a Lead, Ticket or Installment, assigned to one Staff member. Completing it records an outcome and then chooses what comes next: another Followup, a stage action, or closing the record; it is never completed into nothing.
_Avoid_: Task, Reminder, To-do

**Next step**:
What the assignee does next on an open record: for a Lead, its pending Followup or the open Demo or Proposal Ticket under it; for a Ticket, its pending Followup or, failing that, its due date. Every active Lead and unfinished Ticket has one, set when it is created (the **first step**) and renewed each time one is finished. A record without one "needs a next step" and is flagged everywhere the record is listed.
_Avoid_: Action item, Todo

**Deadline**:
The date by which a Lead must be Won or Lost, or a Ticket resolved or closed: its due date, required on both, and never further ahead than the Admin-set limit for that kind of record. Once it has passed the assignee may only look; a Manager or Admin extends it (within the limit again, with a note), reassigns it or closes it.
_Avoid_: Due date (as a loose term for a Followup's time — that is "scheduled for")

**Payment**:
Money owed by a Customer for the Product on a won Lead — a Lead is won the moment the Customer agrees to pay, so a Payment is never recorded before the win. Paid in full, or split into Installments; what has actually arrived is recorded as Receipts.

**Installment**:
A single scheduled portion of a Payment — amount and due date entered manually by the Sales person, not system-generated from a count/split. Each Installment drives an automated reminder Followup ahead of its due date. An Installment is paid once the Receipts against it add up to its amount.

**Receipt**:
Money actually received from a Customer against a Payment (or one of its Installments): amount, date, method and reference. May be smaller than the Installment it is against — several Receipts can together pay one Installment. A Receipt reported by a Product's own application (see Unattached Receipt) arrives before anyone has said which Payment it belongs to.

**Unattached Receipt**:
A Receipt that a Product's application has reported to Forefront (money the Customer paid in the app) that Staff have not yet attached to a Payment or Installment. It carries the Product, the amount, when it was paid, the app's own reference, and the Customer if their phone number matched one. A Sales person, Manager or Admin **attaches** it to exactly one Payment or one Installment of a won Lead (never split), after which it is an ordinary Receipt; attaching needs the Payment to exist already and never exceeds what is still owed. A Manager or Admin may **discard** a duplicate or test one with a note.
_Avoid_: Webhook payment, Incoming payment (it is a Receipt, not a Payment)

**Product**:
What's sold — created by an Admin or Manager, with a name and description but no fixed price: what a sale is worth is the won Lead's actual amount. Every Lead names exactly one Product. A Sales person may only be assigned a Lead for a Product that's been allocated to them; Admins and Managers are unrestricted. A Product may also name its own application's expiry endpoint, which the Expiry pull (see below) calls.
_Avoid_: Assign/Assignment for the Product-to-Sales-person link — say "allocate"/"Allocation" instead, since Assignment already means something specific (who currently owns a Ticket or Lead).

**Ticket**:
A trackable action item connected to a Customer (always), optionally to a Product, and optionally to one Lead. A Lead has many Tickets — the Ticket it was converted from, plus the Tickets for the sales work done under it (a demo, a Proposal); these share the Lead's Customer and Product. A renewal Ticket is never attached to a Lead: it names which Product's Subscription it's about, not which Lead originally sold it. Covers things like a New App Demo or Proposal under a Lead, a Support Demo or Support Call for an existing Customer (never under a Lead), a support issue, a complaint, a feature request, or a Renewal reminder — it is not itself revenue-bearing and is independent of whether a Lead ever exists or wins. Created by any Staff member (Sales person, Manager, or Admin), or by System for a Signup; renewal Tickets are created by the Expiry pull; customer self-service creation is a possible future phase, not current scope. Like a Lead, a Ticket is worked only by its assignee (Managers note, reassign and correct; Admins create, assign and read) and always carries a Next step and a Deadline. A Sales person may **convert** a Ticket into a Lead once they judge the Customer ready to be asked to buy: the new Lead takes the Ticket's Customer, Product and assignee, the Ticket becomes the Lead's first Ticket, and it is resolved. When a Lead is lost, its open Tickets are closed; when it is won, they stay open.
_Avoid_: Support ticket, SupportRequest (not a separate concept — Ticket already covers this ground)

**Subscription**:
The ongoing record of a Customer's access to a Product, created automatically the moment a Lead with a Product is won and given an `expires_at`. One Subscription per won Lead; its `expires_at` is what Renewal reminders and Reclaim eligibility are computed from — it starts as a copy of the originating Lead's `expires_at` but is the one that moves when a renewal pushes the expiry out further — the Expiry pull is what moves it.

**Renewal**:
A Ticket (naming a Customer and a Product, not a Lead) reminding a Sales person to ask a Customer to renew before their Subscription lapses. Opened by System from the Expiry pull once the expiry is within the renewal window (an Admin setting), one open Renewal per Subscription, assigned to the won Lead's current assignee or to the pool. Resolving it records a structured `renewal_outcome` (renewed/declined) — a renewal reward is paid only on "renewed", as a percentage of the original Subscription's Payment total. When the Expiry pull sees the Subscription's expiry move beyond the window, System resolves the open Renewal as renewed.
_Avoid_: Plan Expired (as a Ticket category — lapsing is derived from the Subscription's `expires_at`)

**Expiry pull**:
Forefront asking each Product's own application, once a day, for its active subscriptions and their end dates. For each row whose phone number matches a Customer with a Subscription for that Product, it moves the Subscription's `expires_at` and opens or resolves Renewals; rows that match no Customer or no Subscription are counted and skipped, never turned into Customers or Subscriptions. Scheduled by the host application like the Notification sweep.
_Avoid_: Expiry API, Expiry webhook (the Product's application never calls Forefront about expiry; Forefront calls it)

**Reclaim**:
Re-engaging a Customer whose Subscription for a given Product has already lapsed, once a cooldown period has passed (3 months post-expiry). Represented as a brand-new Lead for that Customer and Product, not a reopened old one. A reclaim reward, when the new Lead is won and paid, is a percentage of that new Lead's own Payment total.
_Avoid_: Expired lead (as a stored status — "expired" is time-based staleness derived from a Subscription's `expires_at`, not a status value stored anywhere)

**Signup**:
A Customer registering themselves in one of the Products' own applications. That application tells Forefront, which finds the Customer by phone number (or creates them) and opens a Ticket, created by System and unassigned, asking for a call to be scheduled. A Signup says nothing about how the Customer heard of the Product — that is a Campaign's job.
_Avoid_: Registration, Lead (a Signup produces a Ticket, not a Lead)

**Unassigned pool**:
The Tickets and Leads that nobody is assigned to yet. A Sales person sees the part of the pool whose Product is allocated to them and may **take** an item (assigning it to themselves); a Manager sees the whole pool and may take any item. Taking stops at the **cap**, an Admin-set number of unfinished Leads one person may hold; a Manager or Admin assigning past the cap is allowed. Admins see and assign from the whole pool but never take, and are never an assignee. Taking is recorded the same way as any other Assignment.

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
A permanent record of one thing a Staff member (or System) did in Forefront — who, what, to which record, what changed, and when — including revealing contact details. Admins see all Audit events; Managers see their team's; Sales persons see none as a log, but every record's page shows its own **Timeline**: the Audit events and notes about that one Ticket or Lead, newest first, to anyone who may open it.

**Notification**:
An alert telling Staff that something needs attention — work left unassigned, stale work, a reveal with no Action, an overdue Installment. Shown in Forefront and sent by email, each one once. Admins set the time limits that decide when each kind fires.

**Proposal**:
The price and terms offered to a Customer for a Lead's Product, asked for and sent through a Ticket under that Lead. May come before or after a demo.
_Avoid_: Quotation, Quote

**Lost reason**:
Why a Lead was lost, chosen from a list Admins maintain, always accompanied by a written note — the reason alone is never enough.
