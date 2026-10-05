Feature: Line filtering
  Background:
    Given a line filter background step

  Scenario: First
    Given a line filter step

  Scenario: Second
    Given a line filter step

  Rule: Outlines
    Scenario Outline: Outline <n>
      Given a line filter step

      Examples:
        | n |
        | 1 |
        | 2 |
