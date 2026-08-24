# Standardize on PostgreSQL; drop SQLite

Forefront targets PostgreSQL exclusively, in both development and production; the gemspec's `sqlite3` dependency is removed. This reverses the gem's earlier implicit goal of running on whatever database a host app already has — Customer/Lead/Ticket search scopes already relied on Postgres-only `ILIKE`, and supporting arbitrary databases would mean rewriting all of them to portable SQL for no current benefit.
