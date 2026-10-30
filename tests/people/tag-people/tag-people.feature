Feature: Tag people with gender and closeness
  As a host
  I want to say who someone is to me and move them from friend to partner
  So that the stack grows with the relationship

  Scenario: Add a person with gender and closeness
    When I add a person "Maya" with gender "Woman" and closeness "Friend"
    Then "Maya" shows "Woman · Friend" on the Profiles list

  Scenario: Closeness defaults to Friend and gender to not set
    When I add a person "Sam" without choosing either
    Then "Sam" is tagged with no gender and closeness "Friend"

  Scenario Outline: Move a person through the relationship
    Given a person "Maya" tagged "Woman" and "<from>"
    When I change "Maya" to closeness "<to>"
    Then "Maya" shows "Woman · <to>"
    And her asked cards and answers are unchanged

    Examples:
      | from   | to      |
      | Friend | Dating  |
      | Dating | Partner |
      | Partner | Dating |
      | Dating | Friend  |

  Scenario: A new closeness unlocks cards in the open stack
    Given a person "Maya" tagged "Woman" and "Friend" and her stack is open
    When I change "Maya" to closeness "Dating"
    Then flirty cards for Everyone, Women and Couples join the end of her stack

  Scenario: Change closeness from the profile screen in one tap
    Given I am on the profile screen of "Maya"
    When I tap "Dating" in the relationship control
    Then the control shows "Dating"

  Scenario: Gender can be set or changed later
    Given a person "Maya" with no gender tag and closeness "Friend"
    When I change her gender to "Woman"
    Then women-only cards that are safe join her stack

  Scenario: Only Woman and Man are offered
    When I open the gender choices
    Then I can choose "Not set", "Woman" or "Man"

  Scenario: Groups have no gender or closeness
    When I open the edit screen of a group
    Then there are no gender or closeness controls

  Scenario: Existing profiles from an older backup are untagged
    Given a backup from before gender and closeness existed
    When I import it
    Then every person has no gender tag and closeness "Friend"

  Scenario: Set who I am
    When I open Settings and choose "I am" "Man"
    Then Settings shows "I am: Man"
    And only "Not set", "Man" and "Woman" are offered
    And the choice is kept after relaunching the app

  Scenario: My own gender is included in the backup
    Given "I am" is "Man"
    When I export and import the database
    Then "I am" is still "Man"
