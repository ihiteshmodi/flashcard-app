Feature: Play the party game on one shared phone
  As a host with friends
  I want to pick people or a group from my profiles, have everyone answer the same black card from shared white-card options in secret, see everyone's answers together at the end, and keep the round in History
  So that we can play with two or more people and remember what everyone picked without repeating questions

  Background:
    Given people "Maya" and "Sam"
    And a set "Family" with black cards and white cards

  Scenario: Starting a two-player game from existing people deals one black card and shared white options
    When I start a game with people "Maya" and "Sam" and the set "Family"
    Then a black card is turned
    And 12 white option cards are ready for the round
    And I am asked to pass the phone to "Maya"
    And no options or picks are shown on the pass screen

  Scenario: Starting a game from a group uses its members as the players
    Given a group "Weekend Crew" with members "Maya" and "Sam"
    When I start a game with the group "Weekend Crew" and the set "Family"
    Then the players in the game are "Maya" and "Sam"

  Scenario: Including Me lets the host play alongside one friend profile
    When I start a game with "Me" and person "Maya" and the set "Family"
    Then the players in the game are "Me" and "Maya"

  Scenario Outline: A game needs between one and ten distinct players and at least one card set
    When I start a game with <setup>
    Then I see "<message>"

    Examples:
      | setup                             | message                            |
      | no players                        | Pick at least one player           |
      | 11 players                        | A game takes at most 10 players    |
      | no set switched on                | Switch on at least one card set    |

  Scenario: Every player sees the same white options and can reuse the exact same answer
    Given a game has started with people "Maya" and "Sam"
    When "Maya" says it is them
    Then "Maya" sees the 12 white option cards for the round
    When "Maya" picks "Ratzilla."
    Then I am asked to pass the phone to "Sam"
    When "Sam" says it is them
    Then "Sam" sees the exact same 12 white option cards with nothing pre-selected
    And "Sam" can also pick "Ratzilla."

  Scenario: Choices stay hidden until everyone has answered, then the reveal shows everyone's named answer
    Given a game has started with people "Maya" and "Sam" on black card "Coming soon! Batman vs. _____."
    When "Maya" says it is them and picks "Ratzilla."
    Then nobody's pick is shown while passing to or choosing as "Sam"
    When "Sam" says it is them and picks "Silence."
    Then the reveal screen shows "Coming soon! Batman vs. _____."
    And it shows "Maya" picked "Ratzilla." and "Sam" picked "Silence."

  Scenario: Multi-blank black cards ask each player for that many distinct cards in order
    Given the black card is "_____ is a slippery slope that leads to _____."
    When "Maya" says it is them
    Then picking only 1 card is refused with "Choose 2 cards"
    And picking the same card twice for the two blanks is refused with "Choose different cards"
    And picking "Ratzilla." then "Silence." keeps that order on the reveal screen

  Scenario: White cards remain reusable in later rounds
    Given the chosen set holds only 5 white cards
    When "Maya" and "Sam" finish round 1 and start round 2
    Then all 5 white cards are still available as options in round 2

  Scenario: Completed rounds are saved in each person's History when playing with people
    Given a game with people "Maya" and "Sam" on "Coming soon! Batman vs. _____."
    When "Maya" picks "Ratzilla." and "Sam" picks "Silence."
    Then "Maya" history includes "Coming soon! Batman vs. _____." with "Ratzilla."
    And "Sam" history includes "Coming soon! Batman vs. _____." with "Silence."

  Scenario: Completed rounds in a group save to the group's History without mixing into members' histories
    Given a group "Weekend Crew" with members "Maya" and "Sam"
    And a game with the group "Weekend Crew" on "Coming soon! Batman vs. _____."
    When "Maya" picks "Ratzilla." and "Sam" picks "Silence."
    Then "Weekend Crew" history includes "Coming soon! Batman vs. _____." with "Maya: Ratzilla." and "Sam: Silence."
    And "Maya" own history has no entry for "Coming soon! Batman vs. _____."

  Scenario: Already-played black cards stay out of future games for those players until reset
    Given the chosen set holds only 2 black cards "One _____." and "Two _____."
    And "Maya" and "Sam" have already played "One _____."
    When I start a new game with people "Maya" and "Sam"
    Then the black card turned is "Two _____."
    When they finish "Two _____." and tap Next Round
    Then I see that all black cards in these sets have been asked
    When I reset asked game cards for these players
    Then "One _____." and "Two _____." can be played again
    And the saved History entries are still kept

  Scenario: Nothing can be done out of turn
    Given a game has started with people "Maya" and "Sam"
    Then submitting cards before saying it is you is refused
    And starting the next round before everyone has answered is refused

  Scenario: A game in progress survives closing and reopening the app, and ending clears it
    Given a game with "Maya" and "Sam" where "Maya" has answered and it is "Sam" turn
    When the app is closed and opened again
    Then the game resumes on "Pass the phone to Sam" with the same black card, options and "Maya" hidden pick
    When I end the game
    Then there is no game in progress to resume
