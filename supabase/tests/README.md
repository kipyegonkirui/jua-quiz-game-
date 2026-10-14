# SQL smoke tests (plain Postgres, no Supabase needed)

`stub.sql` fakes the few Supabase pieces the migrations rely on (`auth.users`, `auth.uid()`, roles).
`run.sh <supabase_dir> <db> file1.sql file2.sql ...` creates a database, loads the stub and runs the
migrations in the order given, printing any errors. `scenario.sql` / `scenario2.sql` play through
Practice, Speed Quiz, Guess It and Odd One Out levels (stars, lives, abandon, gates, ad unlocks).

Order used (see MIGRATION_ORDER.md): schema, 002, 003_phase1, 004_more_questions, seed_kenya_questions,
seed_kenya_questions_batch2, 005, 006_rewarded, 007, 008_guest, 009, 010_speed, 011, 013, 014, 015, 016,
017, 018, 019, 020_odd_one_out, 020_practice_difficulty_and_math, 021, 022, then the later ones.
Expected harmless errors: `schema.sql` line ~225 and `002` (superseded by 003).
Run it against a throwaway database, never production.
