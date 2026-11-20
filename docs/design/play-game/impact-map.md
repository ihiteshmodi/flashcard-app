# Play the party game: impact map

## Vision
A pass-around party game on one shared phone, played with the black and white cards already in the app (see [game cards](../game-cards/impact-map.md)).

## Role
**Host** at a table with 3 to 10 friends, one phone passed from hand to hand. Personal use; no accounts, no network.

## Goal
- Pain: the printed game needs cut cards and a table full of paper.
- Benefit: open the app, type the names, play. Cards are dealt, hands stay private, the Czar judges, points are counted.

Three roles: user plays a round in under a minute of setup; customer is the same person (no revenue); developer keeps the rules in a pure core with no screens, clock or randomness inside, so every rule is tested without the simulator.

## Rules decided with the host
- Each player holds 10 white cards.
- One player is the **Card Czar** each round, rotating in the order the names were typed. The Czar reads the black card and does not play white cards.
- Every other player plays as many white cards as the black card asks for (Pick 1, 2 or 3), in the order they choose them.
- Plays are **anonymous**: the Czar sees the plays in a shuffled order with no names.
- The Czar picks the best play; its player gets 1 point and is named.
- Next round the Czar passes on, hands are topped back up to 10, a new black card is turned.
- **Open-ended**: no target score and no winner is declared. The scores can be looked at any time, and ending the game shows the final scores.
- **Hands are hidden**: the screen says "Pass the phone to Maya"; Maya's cards show only after she says it is her.
- Any of the card sets can be switched on per game; a card in two switched-on sets is dealt once.
- A game in progress is kept, so closing the app does not lose it.

## Capabilities
1. Start a game: names, card sets, ten cards each, first black card.
2. Play a round: pass the phone, hidden hand, choose cards, the Czar judges, the winner is named.
3. Keep playing: Czar rotates, hands refill, used cards come back when a pile runs out.
4. See the scores and end the game.
5. Pick up a game that was in progress.

## Out of scope
Several phones, a target score or a winner, house rules (gambling, Rando Cardrissian), custom cards, sound.

## Features
| Feature | Folder |
|---|---|
| Play the game | `tests/play/play-game/` |

## Guesses
- 3 to 10 players is enough for one phone; the Czar plus two players is the smallest round worth playing.
- Names are typed fresh (the last names are remembered), not taken from the conversation profiles.
