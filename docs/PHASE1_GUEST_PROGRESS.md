# Phase 1 — Guest Progress Persistence

Jua Quiz does not require an account to keep playing.

## Guest behavior

- XP, level, streaks, challenge totals, practice totals, coins, and best scores are mirrored to device storage.
- The guest cache is device-scoped, so refreshing/changing the anonymous Supabase session does not intentionally erase local progress while the app remains installed.
- Supabase remains the authoritative source for rewards and completed gameplay; the local store is a persistence/cache layer for the guest experience.
- The app can be used without signing up or signing in.

## Account behavior

- Creating an account from the guest flow attaches the email to the existing Supabase user, so server-side history stays with the same user.
- Logging into an existing account restores that account's server-side profile/history.
- The device guest cache is not used as an account replacement after login.
- Uninstalling the app removes device-local guest storage. A linked account is therefore the recovery mechanism after reinstalling.

## Verification

After installing the patched build:

1. Start as Guest.
2. Complete a practice round.
3. Open Stats and confirm XP and Practice rounds are no longer zero.
4. Leave/re-enter Stats and confirm the values remain.
5. Restart the app and confirm the guest values remain.
6. Complete another round and confirm values increase once.
7. Later, create an account and verify the same progress is still available.
8. After reinstalling, log in with the same account and verify server-side progress is restored.
