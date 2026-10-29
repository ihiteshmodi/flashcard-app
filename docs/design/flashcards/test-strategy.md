# Test strategy

Option A from `test-strategy`: use cases against a real in-memory SQLite, plus a few UI flows on the simulator. Behaviour is tested through the public services, never private helpers.

| Level | What | How |
|---|---|---|
| 1 pure | Option labels, file names, name keys | table tests |
| 2 state | `CardSession` undo/redo/skip transitions (one test per arrow and per forbidden arrow) | `CardSessionTests` |
| 3 use case | Every `.feature` scenario | `Flashcards` services over `Database.inMemory()`, fixed `Roles`, `World` builder |
| 4 adapter | Real SQLite file: export/import, migrations, seed upsert | temp files, an old-schema fixture built in the test |
| 5 E2E | Add person, swipe, answer, group flow on the simulator | XCUITest with demo data and an in-memory database |
| 6 incoming | SwiftUI views stay thin, covered by E2E | — |

Fixtures: `World` (tests/support) builds people, decks and cards from domain words. Clock advances 1 second per call; shuffle is identity (cards in deck order); ids are counters. Test data is made up, never the private source content.

Commit phase (every commit): `swift test`. Acceptance phase: `xcodebuild test` of the UI tests on the simulator.

Mutation check per feature: break the rule on purpose, see red, restore.

Scenario to test mapping: each test is named after its scenario, e.g. `testSwipingRightMarksTheCardAskedForThisProfileOnly`.
