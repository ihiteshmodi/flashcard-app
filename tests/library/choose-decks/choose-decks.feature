Feature: Choose decks
  As a host
  I want to pick which decks a profile draws from
  So that a group of friends does not get the dares meant for a partner

  Background:
    Given decks "Deep Talk" (3 cards) and "Dares" (2 cards)
    And a profile "Maya"

  Scenario: New profiles draw from all decks
    When I open the stack for "Maya"
    Then the stack contains 5 cards

  Scenario: Deselect a deck
    When I turn off "Dares" for "Maya"
    And I open the stack for "Maya"
    Then the stack contains 3 cards, all from "Deep Talk"

  Scenario: Deck choice is per profile
    Given I turned off "Dares" for "Maya"
    When I open the stack for "Sam"
    Then the stack contains 5 cards

  Scenario: At least one deck must stay on
    Given only "Deep Talk" is on for "Maya"
    When I try to turn off "Deep Talk"
    Then I see "Keep at least one deck on"
    And "Deep Talk" stays on

  Scenario: Deck list shows progress for the profile
    Given "Maya" was asked 2 of 3 "Deep Talk" cards
    Then the deck row shows "2 of 3 asked"

  Scenario: Bundled decks match the source
    Then the app contains the 8 source decks
    And "Couple cards" has Conflicted, This or That, Curious and Cozy Up as categories
    And "X-Rated" has levels 1 to 4 as categories
    And every card text is exactly as in the source, including words like "gf"
