Feature: Export and import the database
  As a host
  I want the whole database as one SQLite file in a folder I choose
  So that I can back it up whenever I want and move it between builds

  Scenario: Export
    Given profiles, asked cards and answers exist
    When I tap Export Database and choose a folder in Files
    Then a file "flashcards-2026-10-29.sqlite" is saved there
    And opening it shows the same profiles, asked cards and answers

  Scenario: Export contains everything
    Given profiles "Maya" and "Sam", deck choices, asked marks, answers and one custom card
    When I export
    Then the file holds all of them for every profile

  Scenario: Export while the app is in use stays consistent
    Given I swiped a card a moment ago
    When I export
    Then the exported file contains that swipe

  Scenario: Export is cancelled
    When I tap Export Database and cancel the folder picker
    Then nothing is written
    And I see no error

  Scenario: Import a valid file
    Given a valid exported file with profile "Maya" and 5 asked cards
    When I import it and confirm "Replace all current data?"
    Then "Maya" has 5 asked cards
    And a backup of the previous database was kept before replacing

  Scenario: Import refuses a file that is not a flashcards database
    Given a SQLite file with unrelated tables
    When I import it
    Then I see "This file is not a Flashcards backup"
    And current data is unchanged

  Scenario: Import refuses a newer schema than the app knows
    Given an export from schema version 99
    When I import it
    Then I see "This backup is from a newer version of the app. Update the app first."
    And current data is unchanged

  Scenario: Import migrates an older schema
    Given an export from schema version 1 and the app is at version 2
    When I import it
    Then the data is upgraded and nothing is lost

  Scenario: Import is cancelled at the confirmation
    When I choose a file and cancel the confirmation
    Then current data is unchanged

  Scenario: Seed cards are not duplicated by import or update
    Given the app is updated with a deck that has a corrected card
    Then existing asked marks and answers still point to the same cards
