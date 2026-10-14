# Phase 1 Step 13 — Coin Economy

The coin economy is server-authoritative. Flutter provides balance presentation, spend requests, and ledger mapping.

## Server

`011_coin_economy.sql` adds:

- expanded coin ledger reasons
- `get_coin_balance()`
- `spend_coins(amount, reason, ref)`
- `get_coin_ledger(limit)`

Authenticated clients can spend coins through the explicit allowlist. Coin grants remain restricted to server-owned flows.

## Flutter

- `CoinTransaction` maps ledger rows.
- `CoinSpendResult` maps spend results.
- `CoinEconomyService` centralizes local affordability/presentation rules.
- `SupabaseService` synchronizes the current profile coin balance after authoritative reads/spends.

No wallet screen is introduced in this step; this creates the API used by future hints, streak shields, cosmetics, chests, missions, and rewards.
