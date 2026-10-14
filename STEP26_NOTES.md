# Step 26 — Practice level load diagnostics

This build keeps the Step 25 Practice Journey and upward roadmap flow intact.
It fixes the generic Practice load failure screen so server errors are surfaced
in a useful, user-readable form. It also logs the underlying exception in debug
mode.

No Supabase schema change is included in this step.

If a level still fails to start, the screen will now identify whether the cause
is a stale open round, previous-level gate, batch gate, missing questions, or
authentication. That exact message can then be used for the next targeted fix.
