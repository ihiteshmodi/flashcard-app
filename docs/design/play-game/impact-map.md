# Play the party game: impact map

## Vision
A pass-around question-and-answer party game on one shared phone, using the black prompt cards and white answer cards in the app (see [game cards](../game-cards/impact-map.md)) and the People and Groups already in Profiles.

## Role
**Host** with friends (2 players or more, on one shared phone passed around). Personal use; no accounts, no network.

## Goal
- Pain: typing names from scratch loses who played what, a 3-player Card Czar rule blocks two-person play, and separate hands hide good answers from other players.
- Benefit: tap the People or Group you already created, pass the phone so everyone answers the same black card from the same round pool of white cards in secret, see everyone's picks together at the end of the round, and keep the round in Profile History without repeating black cards until reset.

Three roles: user starts in seconds and keeps memories in History; customer is the same person (no revenue); developer keeps the rules in a pure core with no UI, clock or randomness inside, tested in memory without the simulator.

## Rules decided with the host
- **Pick existing People or a Group**:
  - Tap a **Group** to play as that group (using its members), or tap individual **People** from Profiles.
  - An optional **"Include Me"** toggle lets the host join as a player without needing a separate profile, and **New Person** lets you add someone new on the spot.
  - No 3-player requirement: 2 players (or any 1 to 10 players) can play.
- **Everyone answers (no Card Czar, no points)**:
  - Each round turns one unasked **black card** and deals **12 white cards** for that round (drawn from the black card's set first when enabled, otherwise the enabled sets).
  - **Every player sees the exact same 12 white cards** for that round.
  - **Answers are reusable**: two or more players can pick the exact same white card(s) in the same round, and white cards stay available for future rounds.
- **Choices stay hidden until the reveal**:
  - Before each turn, a pass screen says "Pass the phone to Maya"; cards appear only after tapping "I'm Maya".
  - While choosing, a player never sees what earlier players picked.
  - Each player picks as many distinct white cards from the round's options as the black card asks for (Pick 1, 2 or 3, in order).
- **Final reveal screen per round**:
  - Once the last player locks in their choice, the reveal screen shows the black card and **every player's name alongside the white card(s) they selected**.
- **Saved to History & no repeat black cards until reset**:
  - Finishing a round records the black card and everyone's answers in History:
    - Under the **Group's History** when playing as a group (without mixing into individual members' histories, matching the Cards tab).
    - Under **each selected Person's History** when playing with individual people.
  - Played black cards stay out of future games for that Group (or those People) until all black cards in the chosen sets have been played and you **Start Over / Reset** asked game cards (saved History entries are kept).
- **Resumable**: a game in progress is saved after every move so closing the app does not lose it.

## Capabilities
1. Start a game by tapping existing People or a Group (plus optional "Me" and quick New Person), with 1–10 players and chosen card sets.
2. Play a round where every player sees the same 12 white cards in secret and can reuse any answer.
3. Reveal the black card and every player's chosen answer(s) with their name once everyone has answered.
4. Save completed rounds to Profile / Group History, skip already-played black cards, and allow resetting asked black cards while keeping History.
5. Resume an in-progress game or end it at any time.

## Out of scope
Several phones over network, Card Czar judging or point scoring, house rules, sound.

## Features
| Feature | Folder |
|---|---|
| Play the game | `tests/play/play-game/` |

## Validated vs. guesses
- **Validated by the owner**: select existing People or a Group; record questions and answers in History; no 3-player minimum (works for 2 players too); everyone answers the black card; white cards can be reused by multiple players; everyone sees the round's white cards; selections stay hidden until the final reveal screen showing the question and each player's named selection; already-played black cards stay out of future games until reset.
- **Note on source PDFs**: Cards Against Humanity PDFs group cards by edition rather than linking specific white cards to a single black card, so each round draws 12 white cards for everyone to share for that black card.
