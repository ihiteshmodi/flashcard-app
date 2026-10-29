Feature: Save and review answers
  As a host
  I want to optionally keep what a person answered
  So that I can recall it before we meet again

  Background:
    Given a profile "Maya"
    And a question card "What foreign country would you love to live in?"

  Scenario: Save a typed answer after swiping right
    Given the card is on top
    When I swipe right
    Then a note sheet slides up
    When I type "Portugal" and tap Save
    Then the card is asked for "Maya"
    And "Maya" history shows the card with the answer "Portugal"

  Scenario: Dismissing the note sheet saves nothing but the card is asked
    Given the card is on top
    When I swipe right
    And I dismiss the note sheet
    Then the card is asked for "Maya"
    And "Maya" history shows the card with no answer

  Scenario: Empty note is treated as no answer
    When I swipe right and tap Save with an empty note
    Then "Maya" history shows the card with no answer

  Scenario: Multiple choice records the picked option
    Given a card "Spinach in their teeth. Do you...": a "Tell them instantly", b "Pretend you did not notice", c "Put food in your own teeth"
    When I swipe right
    And I pick "b" and tap Save
    Then "Maya" history shows the card with the pick "b: Pretend you did not notice"

  Scenario: This or that records the picked side
    Given a card "Never text first again" OR "Never end a call first"
    When I swipe right, pick "Never end a call first" and add the note "she laughed"
    Then "Maya" history shows the pick "Never end a call first" and the note "she laughed"

  Scenario: Multiple choice without a pick is still asked
    When I swipe right on the multiple choice card and dismiss the sheet
    Then the card is asked for "Maya" with no pick

  Scenario: Dares record asked only
    Given a dare card "Lock eyes for 30 seconds"
    When I swipe right
    Then no note sheet appears
    And the card is asked for "Maya"

  Scenario: Review a profile's history
    Given "Maya" was asked three cards, one with an answer
    When I open the history for "Maya"
    Then I see three entries, newest first
    And I can filter to "With answers" and see one

  Scenario: Edit an answer later
    Given "Maya" has the answer "Portugal" for the card
    When I change it to "Portugal or Spain" in history
    Then history shows "Portugal or Spain"

  Scenario: Undo keeps the answer but hides the entry until the card is asked again
    Given I swiped right and saved "Portugal"
    When I tap Undo
    Then "Maya" history has no entry for the card
    When I tap Redo
    Then "Maya" history shows the card with the answer "Portugal"
