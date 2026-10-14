# Phase 1 Step 7 — Test Fix

## Issue
`test/game/game_controller_test.dart` had the `local scoring is exposed only when the mode opts in` test outside `main()`. That made the test's local `session`, `now`, and `questions` declarations out of scope and caused Dart parser errors around line 172.

## Fix
Moved the test back inside `main()` and retained the package-style imports for game code.

## Expected result on developer machine
`flutter test` should compile `game_controller_test.dart` again. The production `GameController` implementation was not changed by this fix.
