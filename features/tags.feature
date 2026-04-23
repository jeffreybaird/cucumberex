@feature_tag
Feature: Tags

  @smoke @fast
  Scenario: Smoke scenario
    Given a passing step

  @wip
  Scenario: WIP scenario
    Given a passing step

  Scenario: Untagged scenario
    Given a passing step

  @slow
  Scenario: Slow scenario
    Given a passing step
