Feature: Data Tables
  Scenario: Table with headers
    Given the following users:
      | name  | email           |
      | Alice | alice@test.com  |
      | Bob   | bob@test.com    |
    Then there should be 2 users

  Scenario: Doc string
    Given a blog post with content:
      """
      Hello, world!
      This is a blog post.
      """
    Then the post should have content "Hello, world!"
