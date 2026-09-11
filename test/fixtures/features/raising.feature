Feature: Raising steps
  A feature whose only step deliberately raises, used to exercise how
  formatters report an exception from a step definition.

  Scenario: A step raises an exception
    Given the world is missing a key
