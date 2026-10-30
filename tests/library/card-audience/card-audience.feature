Feature: Show each person the cards that suit them
  As a host
  I want cards labelled by who they are for and how spicy they are
  So that a friend never gets an explicit card and a partner gets the whole range

  Background:
    Given I am a "Man"
    And a deck "Mixed" with these cards:
      | card                    | who it is for | how spicy | worded for |
      | Favourite flower?       | Everyone      | Safe      | Anyone     |
      | Favourite fragrance?    | Women         | Safe      | Anyone     |
      | Do you like my beard?   | Everyone      | Safe      | A man's view |
      | First kiss story?       | Everyone      | Flirty    | Anyone     |
      | Dream couple holiday?   | Couples       | Safe      | Anyone     |
      | Pick a slow dance       | Couples       | Flirty    | Anyone     |
      | Dare: blindfold         | Couples       | Explicit  | Anyone     |
      | Men only banter         | Men           | Safe      | Anyone     |

  Scenario Outline: What each kind of profile is shown
    Given a person "<name>" tagged "<gender>" and "<closeness>"
    When I open the stack for "<name>"
    Then the stack contains exactly "<cards>"

    Examples:
      | name | gender | closeness | cards                                                                                                                               |
      | Maya | Woman  | Friend    | Favourite flower?, Favourite fragrance?, Do you like my beard?                                                                      |
      | Maya | Woman  | Dating    | Favourite flower?, Favourite fragrance?, Do you like my beard?, First kiss story?, Dream couple holiday?, Pick a slow dance         |
      | Maya | Woman  | Partner   | Favourite flower?, Favourite fragrance?, Do you like my beard?, First kiss story?, Dream couple holiday?, Pick a slow dance, Dare: blindfold |
      | Sam  | Man    | Friend    | Favourite flower?, Do you like my beard?, Men only banter                                                                           |

  Scenario: A person with no gender tag only sees Everyone and Safe cards
    Given a person "Riley" with no gender tag but closeness "Partner"
    When I open the stack for "Riley"
    Then the stack contains exactly "Favourite flower?, Do you like my beard?"

  Scenario: A group only sees Everyone and Safe cards
    Given a group "Game Night" with member "Maya"
    When I open the stack for "Game Night"
    Then the stack contains exactly "Favourite flower?, Do you like my beard?"

  Scenario: Cards worded from a man's view are hidden when I am not a man
    Given I change "I am" to "Woman"
    And a person "Maya" tagged "Woman" and "Friend"
    When I open the stack for "Maya"
    Then the stack contains exactly "Favourite flower?, Favourite fragrance?"

  Scenario: Without an "I am" setting no card worded from a specific view is shown
    Given "I am" is not set
    And a person "Maya" tagged "Woman" and "Friend"
    When I open the stack for "Maya"
    Then the stack contains exactly "Favourite flower?, Favourite fragrance?"

  Scenario: Changing "I am" updates every stack
    Given a person "Maya" tagged "Woman" and "Friend"
    And I opened the stack for "Maya"
    When I change "I am" to "Woman"
    Then "Do you like my beard?" is no longer in the stack for "Maya"

  Scenario: Progress counts only the cards this profile can be asked
    Given a person "Maya" tagged "Woman" and "Friend"
    When I open the stack for "Maya"
    Then the progress is "0 of 3"

  Scenario: Cards hidden by the labels stay in history if they were asked before
    Given "Dare: blindfold" was asked for "Maya" while she was a "Partner"
    When I change "Maya" to "Friend"
    Then the history for "Maya" still shows "Dare: blindfold"
    And the stack for "Maya" does not contain it

  Scenario: Deck switches and labels work together
    Given a person "Maya" tagged "Woman" and "Partner"
    When I turn off the deck "Mixed" for "Maya"
    Then the stack for "Maya" is empty

  Scenario: The bundled decks are labelled
    Given the bundled decks are loaded
    Then every dare in "X-Rated" level 1 is "Couples" and "Flirty"
    And every dare in "X-Rated" levels 2 to 4 is "Couples" and "Explicit"
    And every card in "21 Questions" except the last one is "Everyone" and "Safe"
    And "Conversation Topics" cards are "Women", "Flirty" and worded from a man's view
