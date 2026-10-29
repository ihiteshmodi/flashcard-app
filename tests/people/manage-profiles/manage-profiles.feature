Feature: Manage profiles
  As a host
  I want a profile per person or group
  So that each has its own asked list and answers

  Scenario: Create a profile
    When I add a profile named "Maya" with the emoji "🌸"
    Then "Maya" is in the profile list and selected

  Scenario: Name is required
    When I add a profile with an empty name
    Then I see "Enter a name"
    And no profile is created

  Scenario: Duplicate names are refused
    Given a profile "Maya"
    When I add a profile named "maya"
    Then I see "A profile named Maya already exists"

  Scenario: Rename a profile keeps its history
    Given "Maya" has 5 asked cards
    When I rename "Maya" to "Maya R."
    Then "Maya R." has 5 asked cards

  Scenario: Delete needs confirmation
    Given "Maya" has 5 asked cards
    When I tap Delete Profile
    Then I am asked to confirm "Delete Maya and 5 answers?"
    When I confirm
    Then "Maya" and her history are gone

  Scenario: Cancel delete
    When I tap Delete Profile and cancel
    Then "Maya" is unchanged

  Scenario: The last used profile is selected on launch
    Given I last used "Sam"
    When I relaunch the app
    Then "Sam" is selected

  Scenario: First launch with no profiles
    Given no profiles exist
    When I open the app
    Then I see "No profiles yet. Add your first profile." with an Add Profile button
