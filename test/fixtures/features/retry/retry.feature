Feature: Retries

  @always_fails
  Scenario: Always fails
    Given a retry step that always fails

  @flaky
  Scenario: Flaky
    Given a retry step that fails only the first time

  @passes
  Scenario: Passes
    Given a retry step that passes
