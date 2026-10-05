Feature: Around hooks

  @around_order
  Scenario: Wrapped
    Given an around step

  @around_world
  Scenario: Sees the world from the around hook
    Given an around step that checks the world

  @around_no_run
  Scenario: Hook never runs the scenario
    Given an around step

  @around_raise_before
  Scenario: Hook raises before running the scenario
    Given an around step

  @around_raise_after
  Scenario: Hook raises after running the scenario
    Given an around step

  @around_nested
  Scenario: Nested hooks
    Given an around step

  @around_failing_step
  Scenario: Step fails inside the hook
    Given an around step that fails

  Scenario: Untagged
    Given an around step
