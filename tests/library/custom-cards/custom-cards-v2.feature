Feature: Add my own cards with everything built-in cards have
  As a host
  I want my own cards to carry the same details as the bundled ones
  So that they are filtered, grouped and shown the same way

  Scenario: Fields offered when creating a card
    When I open New Card
    Then I can choose the kind: Question, This or That, Multiple Choice or Dare
    And I can choose the deck: My Cards or any built-in deck
    And I can type a category or pick one that exists in the chosen deck
    And I can add a tip or detail line
    And I can choose who it is for: Everyone, Women, Men or Couples
    And I can choose how spicy: Safe, Flirty or Explicit
    And I can choose who it is worded for: Anyone, A man's view or A woman's view

  Scenario: Defaults
    When I add the question "What is your comfort movie?" without changing anything
    Then it is in "My Cards" with no category, Everyone, Safe and Anyone

  Scenario: Add a card into a built-in deck under a category
    When I add the question "What is your biggest fear?" to the deck "21 Questions" under the category "Inner World & Perspective"
    Then it appears in the "21 Questions" deck list under that category
    And it is still editable and deletable, unlike the bundled cards

  Scenario: My card in a built-in deck survives a bundled deck update
    Given I added a card to the deck "21 Questions"
    When the bundled "21 Questions" deck is loaded again
    Then my card is still there

  Scenario: Add a dare
    When I add the dare "Hold hands for a minute" with the detail "no talking"
    Then no answer sheet opens when it is swiped right
    And the card shows the detail line

  Scenario: Add a card with a tip line
    When I add the question "Best trip?" with the tip "Why it works: it invites a story"
    Then the card shows the tip under the question

  Scenario Outline: My labels decide who sees my card
    Given I added the question "My card" for "<who>" and "<spicy>"
    And a person "Maya" tagged "Woman" and "<closeness>"
    When I open the stack for "Maya"
    Then "My card" is in the stack: <shown>

    Examples:
      | who     | spicy    | closeness | shown |
      | Everyone | Safe    | Friend    | yes   |
      | Women   | Safe     | Friend    | yes   |
      | Men     | Safe     | Friend    | no    |
      | Couples | Safe     | Friend    | no    |
      | Couples | Safe     | Dating    | yes   |
      | Everyone | Explicit | Dating   | no    |
      | Everyone | Explicit | Partner  | yes   |

  Scenario: Editing labels updates every open stack
    Given my card "My card" is "Couples" and "Safe" and Maya is a "Friend" with her stack open
    When I change it to "Everyone"
    Then it joins Maya's stack

  Scenario: Existing own cards get the defaults after the update
    Given an own card created before labels existed
    When the app is updated
    Then it is "Everyone", "Safe" and "Anyone"

  Scenario: Text is still required
    When I add a card with empty text
    Then I see "Enter the question"

  Scenario: A category needs a deck
    When I type a category but the deck is "My Cards"
    Then the card is saved under that category inside "My Cards"
