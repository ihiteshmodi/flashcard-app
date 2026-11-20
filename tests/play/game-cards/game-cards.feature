Feature: Game cards
  As a host at a table with friends
  I want black prompt cards and white answer cards on the phone, grouped in sets
  So that a round of the party game can start without printed cards

  Background:
    Given a set "Family" with black card "Coming soon! Batman vs. _____." and white card "Ratzilla."
    And a set "Adult" with black card "What ended my last relationship?" and white card "Ratzilla."

  Scenario: Family Edition ships with the app
    When the app starts
    Then the set "Family Edition" has black cards and white cards
    And every black card contains a blank or is a question
    And every card has an id that no other card has

  Scenario: A black card with one blank asks for one white card
    When I look at the black card "Coming soon! Batman vs. _____."
    Then it asks for 1 white card

  Scenario: A black card with two blanks asks for two white cards
    Given a black card "_____ is a slippery slope that leads to _____."
    Then it asks for 2 white cards

  Scenario: A question card asks for one white card
    When I look at the black card "What ended my last relationship?"
    Then it asks for 1 white card

  Scenario: Only the enabled sets are dealt
    When I enable only the set "Family"
    Then the black cards are "Coming soon! Batman vs. _____."
    And the white cards are "Ratzilla."

  Scenario: A card in two enabled sets is dealt once
    When I enable the sets "Family" and "Adult"
    Then the white cards are "Ratzilla." once
    And the black cards are "Coming soon! Batman vs. _____." and "What ended my last relationship?"

  Scenario: The private sets are missing
    Given the private card file is not in the app
    When the app starts
    Then only the set "Family Edition" is offered
    And I see no error

  Scenario: The card file cannot be read
    Given a card file that is not valid
    When the app starts
    Then I see "The card data could not be read" with the reason
