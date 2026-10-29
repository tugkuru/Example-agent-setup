---
name: test-generation-skill
description: Rules for writing and updating automated tests (unit and integration) - scope, naming, Arrange-Act-Assert, test doubles and edge cases. Use when adding tests for new or changed code, reproducing a bug with a failing test, or reviewing and fixing existing tests.
---

# Test generation

Stack-neutral rules for tests in this repository. Follow the project's existing test framework, folder layout and
helpers; these rules decide *what* to test and *how* to shape it.

## Before writing

1. Find the existing tests for the code under test and match their style, location and helpers.
2. Identify the behavior to cover: the public contract of the unit, not its internals.
3. For a bug fix, write the test that reproduces the bug first and confirm it fails for the right reason.

## Scope

- **Test behavior, not implementation.** Assert on outputs, state changes and calls across boundaries, never on
  private methods or internal data structures.
- **Pick the lowest level that proves the behavior.** Unit tests for logic; integration tests for wiring,
  persistence, serialization and external contracts. Don't duplicate the same assertion on every level.
- **Cover what you changed.** Every behavioral change gets a test that would fail without it. Don't add tests for
  untouched code unless asked.
- **No tests for trivial code** (plain getters, generated code, framework configuration) unless it has logic.

## Naming

- Name the test after the behavior and the condition: `<unit>_<does what>_when_<condition>` or the equivalent
  convention already used in the project.
- A failing test name alone should tell the reader what broke.
- Use the domain terms from `docs/glossary.md` in test names and test data.

## Structure: Arrange – Act – Assert

- **Arrange:** build only the data this test needs. Use builders or factories the project already has.
- **Act:** exactly one call to the behavior under test.
- **Assert:** check the outcome that matters for this behavior. Several assertions are fine if they describe one
  outcome.
- Separate the three blocks with a blank line. No comments naming the blocks.
- No logic in tests: no loops, conditionals or computed expected values. Use parameterized tests for variations.
- Tests are independent: no shared mutable state, no reliance on execution order, no real clock, randomness or
  network. Inject time and random sources.

## Test doubles

- **Prefer real objects** for value types and pure logic.
- **Fake or stub** what is slow, non-deterministic or external: network, file system, clock, message brokers, third
  party APIs.
- **Mock** only to verify an interaction that *is* the behavior (e.g. "an event is published"). Don't verify calls
  that are incidental.
- Don't mock the unit under test, and don't mock types you don't own when a thin adapter can be faked instead.
- For persistence, prefer the project's integration setup (e.g. an in-memory or containerized database) over
  mocking the data access layer.

## Edge cases

Go through this list and test each case that applies to the behavior:

- Empty, missing and null inputs; empty collections.
- Boundaries: zero, one, many; minimum and maximum values; off-by-one around limits.
- Invalid input and the expected error (type and message or code, not just "throws").
- Duplicates, ordering, and case or whitespace variations in text.
- Time: time zones, day and month boundaries, leap years, expiry exactly at the limit.
- Concurrency and retries, if the code is meant to handle them.
- Authorization: the action is denied for a caller without permission.

## Test data

- Use obviously fake data. **Never use real credentials, tokens or personal data** in fixtures, snapshots or logs.
- Keep data minimal and local to the test; only values that influence the outcome should stand out.

## Done when

- The new tests fail without the change and pass with it.
- The project's full test command passes, not just the new tests.
- Report which tests you added or changed, and any case from the list above you deliberately left out and why.
