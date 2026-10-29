Feature: Swipe cards
  As a host with a profile selected
  I want to swipe through cards that this person has not been asked
  So that every conversation stays fresh

  Background:
    Given a deck "Deep Talk" with cards "Q1", "Q2", "Q3"
    And profiles "Maya" and "Sam", both drawing from "Deep Talk"

  Scenario: A new profile sees every card in some order
    When I open the stack for "Maya"
    Then the stack contains "Q1", "Q2", "Q3" in a shuffled order

  Scenario: Swiping right marks the card asked for this profile only
    Given I am on the stack for "Maya" and the top card is "Q1"
    When I swipe right
    Then "Q1" is asked for "Maya"
    And the next card is shown
    And the stack for "Sam" still contains "Q1"

  Scenario: An asked card never comes back for the same profile
    Given "Q1" is asked for "Maya"
    When I open the stack for "Maya"
    Then the stack contains "Q2", "Q3" only

  Scenario: Swiping left skips the card and it comes back later
    Given I am on the stack for "Maya" and the top card is "Q1"
    When I swipe left
    Then "Q1" is not asked for "Maya"
    And "Q1" is at the end of the stack

  Scenario: Switching profile changes the stack
    Given "Q1" and "Q2" are asked for "Maya"
    When I switch to "Sam"
    Then the stack contains "Q1", "Q2", "Q3"

  Scenario: Undo reverses the last swipe
    Given I swiped right on "Q1" for "Maya"
    When I tap Undo
    Then "Q1" is the top card again
    And "Q1" is not asked for "Maya"

  Scenario: Undo keeps the saved answer
    Given I swiped right on "Q1" for "Maya" and saved the answer "Lisbon"
    When I tap Undo
    Then "Q1" is the top card again
    And "Q1" is not asked for "Maya"
    When I swipe right on "Q1" again
    Then the note sheet shows "Lisbon"

  Scenario: Redo re-applies an undone swipe
    Given I swiped right on "Q1" for "Maya" and tapped Undo
    When I tap Redo
    Then "Q1" is asked for "Maya"
    And the next card is shown

  Scenario: Redo also restores a skip
    Given I swiped left on "Q1" and tapped Undo
    When I tap Redo
    Then "Q1" is at the end of the stack

  Scenario: A new swipe clears Redo
    Given I swiped right on "Q1" and tapped Undo
    When I swipe right on "Q1" again
    Then the Redo button is disabled

  Scenario: Undo and Redo with nothing to do
    Given I have not swiped yet
    Then the Undo button is disabled
    And the Redo button is disabled

  Scenario: Everything asked
    Given "Q1", "Q2", "Q3" are asked for "Maya"
    When I open the stack for "Maya"
    Then I see "All asked" and a "Start over" button
    When I tap "Start over"
    Then the stack contains "Q1", "Q2", "Q3"

  Scenario: Start over keeps saved answers
    Given "Q1" is asked for "Maya" with the answer "Lisbon"
    When I start over for "Maya"
    Then "Maya" still has the answer "Lisbon" for "Q1"

  Scenario: Only skipped cards left
    Given "Q1" and "Q2" are asked and "Q3" is skipped for "Maya"
    When I open the stack for "Maya"
    Then the stack contains "Q3"
