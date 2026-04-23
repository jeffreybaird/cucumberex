@belly
Feature: Belly
  In order to avoid overeating
  As a hungry person
  I need to know when to stop eating

  Background:
    Given I am hungry

  Scenario: Eating cukes
    Given I have 5 cukes in my belly
    When I eat 3 cukes
    Then I should have 2 cukes remaining

  @fast
  Scenario: Not eating cukes
    Given I have 5 cukes in my belly
    Then I should have 5 cukes remaining

  Scenario Outline: Eating different amounts
    Given I have <start> cukes in my belly
    When I eat <eat> cukes
    Then I should have <remaining> cukes remaining

    Examples:
      | start | eat | remaining |
      | 10    | 3   | 7         |
      | 8     | 5   | 3         |
      | 5     | 5   | 0         |
