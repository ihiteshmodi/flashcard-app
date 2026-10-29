Feature: Add my own cards
  As a host
  I want to write my own cards
  So that the stack also holds questions I think of myself

  Scenario: Add a question card
    When I add the question "What is your comfort movie?" to "My Cards"
    Then "My Cards" has 1 card
    And "Maya" can see it in the stack

  Scenario: A new card is unasked for every existing profile
    Given "Maya" and "Sam" exist
    When I add the question "What is your comfort movie?"
    Then it is in both stacks

  Scenario: Text is required
    When I add a question with empty text
    Then I see "Enter the question"
    And no card is created

  Scenario: Add a this-or-that card
    When I add "Coffee" OR "Tea"
    Then the card is shown as two options

  Scenario: Add a multiple choice card with at least two options
    When I add a multiple choice card with one option
    Then I see "Add at least two options"

  Scenario: Edit my own card
    Given I added "What is your comfort movie?"
    When I change it to "What is your comfort show?"
    Then the card shows the new text
    And profiles that were asked it keep their answers

  Scenario: Delete needs confirmation and keeps nothing dangling
    Given "Maya" answered my card
    When I delete the card and confirm "Delete card and 1 answer?"
    Then the card and that answer are gone

  Scenario: Bundled cards cannot be edited or deleted
    When I open a bundled card
    Then there is no Edit or Delete action
