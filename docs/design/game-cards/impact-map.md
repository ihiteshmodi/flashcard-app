# Game cards: impact map

## Vision
The card content for a pass-around party game: one black prompt card per round, and white answer cards that players choose from.

## Role
**Host** at a table with friends, one shared phone. Personal use and friends only; no accounts, no network.

## Goal
- Pain: the printed cards are PDFs to cut out and carry.
- Benefit: every card is already on the phone, so a round starts in seconds and nobody cuts paper.

Three roles: user gets a ready deck; customer is the same person (no revenue); developer keeps card content as plain data that the rules code can read without knowing about PDFs.

## Capabilities (this task)
1. Hold black cards (a prompt with blanks, or a question) and white cards (an answer) in named sets.
2. Turn sets on or off per game; only enabled sets are dealt.
3. Know how many white cards a black card asks for (Pick 1, Pick 2).
4. Never deal the same card twice when two enabled sets contain it.

Out of scope here: the game rules and screens, which are built in [play-game](../play-game/impact-map.md), and playing on several phones. Open-ended play with no winner was chosen.

## Source and sets
| Set id | Title | Source PDF | Shipped |
|---|---|---|---|
| `family` | Family Edition | `CAH_FamilyGame-1.1-SmallCards.pdf` (text) | In the repository |
| `main-2022` | Cards Against Humanity 2022 | `CAH_PrintPlay2022-RegularInk` (shapes, read by OCR) | Private, git-ignored |
| `intl`, `uk`, `can`, `aus` | Regional editions | `CAH_PrintPlay_*` (shapes, read by OCR) | Private, git-ignored |

The low-ink PDFs repeat the same cards as the regular ones and add nothing.
Card content is licensed CC BY-NC-SA 2.0 by Cards Against Humanity LLC (the PDFs' own terms page): attribution, non-commercial, share-alike. The adult sets stay out of git, as the other private decks do.

## Features
| Feature | Folder |
|---|---|
| Game cards | `tests/play/game-cards/` |

## Guesses
- Validated by the user: all sets with a per-game toggle; personal use only; shared phone first.
- Still guesses: that the regional editions differ from 2022 only by a few cards; that OCR reads every card exactly (each set is checked by counts and a spot check).
