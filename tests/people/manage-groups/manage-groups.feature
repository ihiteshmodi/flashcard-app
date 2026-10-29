Feature: Manage groups
  As a host
  I want groups made of people I already track
  So that I can ask a friend group its own fresh cards without mixing with individual histories

  Background:
    Given people "Maya", "Sam", "Jordan", "Alex" and "Riley"
    And a deck "Deep Talk" with cards "Q1", "Q2", "Q3"

  Scenario: Create a group from existing people
    When I create a group "College Friends" with the emoji "🍻" and members "Maya", "Sam", "Jordan", "Alex"
    Then "College Friends" is in the Groups list with "4 people"
    And it is selected on the Cards tab

  Scenario: A group needs a name
    When I create a group with an empty name
    Then I see "Enter a name"
    And no group is created

  Scenario: A group needs at least one member
    When I create a group "Game Night" with no members
    Then I see "Pick at least one person"
    And no group is created

  Scenario: Group and person names do not clash
    Given a person "Maya"
    When I create a group named "maya"
    Then I see "A profile named Maya already exists"

  Scenario: Add and remove members
    Given a group "College Friends" with members "Maya", "Sam"
    When I add "Jordan" and remove "Sam"
    Then the members are "Maya", "Jordan"

  Scenario: The last member cannot be removed
    Given a group "Game Night" with member "Riley"
    When I remove "Riley"
    Then I see "A group needs at least one person"
    And "Riley" is still a member

  Scenario: A group has its own asked list
    Given "Q1" is asked for "Maya" and "Sam"
    And a group "College Friends" with members "Maya", "Sam"
    When I open the stack for "College Friends"
    Then the stack contains "Q1", "Q2", "Q3"

  Scenario: Asking a card in a group does not mark it for members
    Given a group "College Friends" with members "Maya", "Sam"
    When I swipe right on "Q1" in "College Friends"
    Then "Q1" is asked for "College Friends"
    And "Q1" is not asked for "Maya"
    And "Q1" is not asked for "Sam"

  Scenario: Group answers are labelled with who answered
    Given I swiped right on "Q1" in "College Friends"
    When I choose "Sam" under "Who answered?" and save "Calls park security"
    Then the group history shows "Sam: Calls park security"
    And "Sam" own history has no entry for "Q1"

  Scenario: Who answered is optional
    Given I swiped right on "Q1" in "College Friends"
    When I save "Everyone laughed" without choosing anyone
    Then the group history shows "Everyone: Everyone laughed"

  Scenario: Who answered lists only current members
    Given a group "Game Night" with members "Riley", "Alex"
    When the note sheet opens
    Then I can choose "Riley", "Alex" or "Everyone"

  Scenario: Group has its own deck choices
    Given "Dares" is turned off for "Maya"
    When I create a group "College Friends" with member "Maya"
    Then "Dares" is on for "College Friends"

  Scenario: Remove a person from a group keeps their answers in the group
    Given "Sam" answered "Q1" in "College Friends"
    When I remove "Sam" from "College Friends"
    Then the group history still shows "Sam: Calls park security"

  Scenario: Deleting a person leaves groups intact
    Given "Sam" is in "College Friends" and answered there
    When I delete the person "Sam"
    Then "Sam" is no longer listed as a member
    And the group history still shows the answer labelled "Sam"
    And "College Friends" is unchanged otherwise

  Scenario: Deleting a group needs confirmation and keeps people untouched
    Given "College Friends" has 3 answers
    When I delete the group and confirm "Delete College Friends and 3 answers?"
    Then the group is gone
    And "Maya", "Sam", "Jordan", "Alex" and their histories are unchanged

  Scenario: Switch between a person and a group
    Given "Maya" is selected
    When I choose "College Friends" in the switcher
    Then the stack, progress and Undo history are those of "College Friends"
