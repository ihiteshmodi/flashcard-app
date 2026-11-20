Feature: Play the party game on one shared phone
  As a host at a table with friends
  I want to deal, play and judge rounds on one phone passed around
  So that we can play without printed cards

  Background:
    Given the players "Maya", "Sam" and "Lee"
    And a set "Family" with enough black and white cards

  Scenario: Starting a game deals ten white cards to each player
    When I start a game with the set "Family"
    Then every player holds 10 white cards
    And a black card is turned
    And the Card Czar is "Maya"
    And everyone has 0 points

  Scenario Outline: A game needs three to ten players with different names
    When I start a game with the players <players>
    Then I see "<message>"

    Examples:
      | players                | message                            |
      | "Maya" and "Sam"       | Add at least 3 players             |
      | 11 different names     | A game takes at most 10 players    |
      | "Maya", "Sam", "maya"  | Each player needs a different name |
      | "Maya", "Sam", " "     | Every player needs a name          |

  Scenario: A game needs a card set
    When I start a game with no set switched on
    Then I see "Switch on at least one card set"

  Scenario: The chosen sets must hold enough cards
    Given the chosen sets hold only 20 white cards
    When I start a game
    Then I see "These sets do not have enough white cards for 3 players"

  Scenario: The hand stays hidden until the player says it is them
    When I start a game
    Then I am asked to pass the phone to "Sam"
    And no hand is shown
    When "Sam" says it is them
    Then "Sam" sees their own 10 cards

  Scenario: Players play in turn and the Czar does not play
    Given a game has started
    When "Sam" plays a card
    Then I am asked to pass the phone to "Lee"
    When "Lee" plays a card
    Then I am asked to pass the phone to the Czar "Maya"

  Scenario: A player plays as many cards as the black card asks for
    Given the black card is "_____ is a slippery slope that leads to _____."
    When "Sam" says it is them
    Then "Sam" must play 2 cards
    And playing 1 card is refused with "Choose 2 cards"

  Scenario: A player can only play cards from their own hand, each once
    Given "Sam" is choosing cards
    Then playing a card that is not in the hand is refused with "That card is not in your hand"
    And playing the same card twice is refused with "Choose different cards"

  Scenario: The Czar sees the plays without names
    Given every player but the Czar has played
    When "Maya" says it is them
    Then the Czar sees 2 plays in a shuffled order
    And no play shows who played it

  Scenario: The Czar picks the best play and its player scores
    Given the Czar is judging
    When the Czar picks the play of "Lee"
    Then "Lee" is named the winner of the round
    And "Lee" has 1 point
    And everyone else has 0 points

  Scenario: The next round passes the Czar on and refills the hands
    Given "Lee" won round 1
    When the next round starts
    Then the Card Czar is "Sam"
    And every player holds 10 white cards
    And a new black card is turned
    And I am asked to pass the phone to "Lee"

  Scenario: Cards played are not dealt again until a pile runs out
    Given the chosen sets hold exactly enough white cards for the hands
    When a round is played and the next round starts
    Then every player holds 10 white cards
    And no card is held twice

  Scenario: The black cards come round again when they run out
    Given the chosen sets hold only 2 black cards
    When 3 rounds are played
    Then a black card is turned each time

  Scenario: Nothing can be done out of turn
    Then playing cards while the Czar is judging is refused
    And picking a play before everyone has played is refused
    And starting the next round before a play is picked is refused

  Scenario: The scores can be seen at any time and the game has no winner
    Given "Lee" won round 1
    Then the scoreboard lists "Lee" with 1 point and the others with 0
    And no winner of the game is declared

  Scenario: A game in progress is kept
    Given a game is in the middle of a round
    When the app is closed and opened again
    Then I can continue the same game with the same hands, scores and black card

  Scenario: Ending the game forgets it
    Given a game is in progress
    When I end the game
    Then I see the final scores
    And there is no game to continue
