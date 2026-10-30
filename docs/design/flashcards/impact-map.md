# Flashcards: impact map

## Vision
An offline iPhone app of conversation cards. You swipe through cards with one person or a group, and the app remembers what each person has already been asked, so they never get a repeat.

## Role
**Host** (the app owner): uses it in person, one-handed, with a partner, a date or a group of friends. One user, one phone, no accounts.

## Goal
- Pain: remembering which questions were already asked to whom; scrolling a notes page; losing good answers.
- Benefit: always a fresh card for this person; answers worth keeping are saved and can be reviewed before the next meeting.

Three roles: user gets fresh conversation and a memory; customer is the same person (personal app, no revenue); developer keeps a small, testable core.

## Capabilities
1. Swipe through a shuffled stack of cards, Tinder style.
2. Keep separate profiles (a person or a group); each has its own asked history.
3. Optionally save the answer (text, or the chosen option) when a card is asked, and review answers per profile.
4. Choose which decks a profile draws from.
5. Add my own cards.
6. Undo the last swipe, and redo it if the undo was a mistake.
7. Export the whole database (all profiles, asked marks, answers, custom cards) as one SQLite file to any location I choose, and import it back. Export is the main use.

## Features
| Feature | Folder |
|---|---|
| Swipe cards | `tests/play/swipe-cards/` |
| Save and review answers | `tests/play/answers/` |
| Manage profiles | `tests/people/manage-profiles/` |
| Manage groups | `tests/people/manage-groups/` |
| Choose decks | `tests/library/choose-decks/` |
| Add my own cards | `tests/library/custom-cards/` |
| Export and import database | `tests/data/backup-database/` |

## Source content (read from the Notion export, kept out of the repo)
Eight dropdowns become eight decks. Six card shapes:

| Shape | Source | Shown on the card |
|---|---|---|
| Question | General, About you guys, Crazy questions, 21 questions | The question, small category label (e.g. "Deep", "Values & Character") |
| Topic with tip | Conversation topics | Prompt on front; "Why it works" tip as secondary text |
| Upgrade | Small talk | The better question; "Instead of: ..." line |
| Dare | X-Rated (levels 1 to 4) | Bold action, italic detail line, level label |
| Multiple choice | Couple cards: Conflicted | Scenario, options a / b / c |
| This or that | Couple cards: This or That | Option A, "OR", option B |

Couple cards also hold Curious (question) and Cozy Up (dare) groups.

## Decisions confirmed with the user
- SwiftUI, local SQLite, fully offline, no accounts.
- Swipe right = asked. Swipe left = skip; a skipped card comes back later.
- After swiping right an optional note sheet slides up; dismissing it saves nothing and the card still counts as asked.
- Two kinds of profile: a person, and a group made of people. They are fully separate: each has its own asked list, answers and deck choices. Asking a card in a group never marks it for members, and a person's history never affects a group's.
- A group lists its members (existing people) and needs a name and at least one member. Members are for display and for labelling who answered.
- In a group, the note sheet has an optional "Who answered?" picker (a member or Everyone). The answer stays in the group's history.
- Dark mode is true black.
- A profile picks one or more decks; the stack draws from them in random order.
- Adult decks shown like any other deck (no gate).
- Multiple choice and This-or-that record the picked option plus optional note. Dares record asked/done only.
- Everything asked: "All asked" screen with "Start over for this profile"; answers are kept.
- Card wording is imported exactly as in the source; no rewrite.
- Undo reverses the swipe but never deletes the saved answer; Redo re-applies the undone swipe.
- Start over clears asked marks only; answers stay.
- A new custom card is unasked for every existing profile.
- Extras in v1: own cards, undo/redo, export/import the SQLite file.

## Assumptions (approved with the mockups)
Confirmed: new profiles start with all decks on; skipped cards go to the end of the stack and stay unasked; start over keeps answers; no wording rewrite; source zip and generated card data stay out of git; new custom cards are unasked for every profile.

Approved together with the mockups:
1. After Undo, the answer stays saved and is pre-filled if the card is asked again. Redo is available until the next new swipe.
2. A saved answer on a card that is currently un-asked (after Undo) does not appear in history until the card is asked again.
3. Export writes a copy of the SQLite file through the iOS Files sheet (or the share sheet) to any location; import validates the file and backs up the current database first.
4. Removing or deleting a person keeps their past group answers, labelled with the name they had when saved.
5. A new group starts with all decks on, like a new person.
6. Names are unique across people and groups.

Decisions made while building (not in the original examples):
- Quotes that only wrap a whole card (for example around a topic title) are dropped when the seed is built; the words are untouched.
- A this-or-that option label drops its trailing "?" and gets a capital first letter, so it reads as a button.
- Own cards can be a question, this-or-that (two options) or multiple choice (two to four options).
- The Appearance setting (System, Light, Dark) defaults to System.
- The "21 Questions" deck is public: it ships in `app/resources/StarterDecks.json` so anyone who builds the app from GitHub starts with 40 questions. All other decks stay private. Both files use the same card ids, so loading both never duplicates a card.

## Delta: audience labels, gender and closeness (approved)
Why: some bundled cards (X-Rated, topics worded for a man asking a woman, couples-only questions) should not be asked to a friend, a man or a group. Own cards must carry the same details as bundled cards.

Cards carry three labels (built-in cards classified once by deck, category and wording; own cards pick them in New Card):
- **Who it is for:** Everyone, Women, Men, Couples.
- **How spicy:** Safe, Flirty, Explicit.
- **Worded for:** Anyone, A man's view, A woman's view (the asker's point of view, e.g. "Do you like it when I wear cologne?").

People carry a **gender** (Woman, Man, or not set; there is no other option) and a **closeness** (Friend, Dating, Partner; default Friend), changeable at any time. The owner sets **I am** (Man or Woman, or not set) in Settings.

A card is shown to a person when all of these hold:
| Rule | Condition |
|---|---|
| Spice | Safe for everyone; Flirty needs Dating or Partner; Explicit needs Partner |
| Audience | Everyone always; Women needs gender Woman; Men needs gender Man; Couples needs Dating or Partner |
| Worded for | "A man's view" needs I am = Man; "A woman's view" needs I am = Woman; unset I am hides both |
| No gender tag | Treated as untagged: only Everyone + Safe + Anyone-worded cards |
| Groups | Same as untagged: only Everyone + Safe cards |

Progress and deck counts count only the cards a profile can see. Cards hidden by a change stay in history. New Card also offers deck (My Cards or any built-in deck), category, tip line and the Dare kind. Own cards in a built-in deck are kept when the bundled deck is reloaded.

Default classification of the bundled decks (applied without a review step, as agreed):
| Deck | Who | Spice | Worded for |
|---|---|---|---|
| General: untitled, Fun, Cute, Deep, Random, Personal | Everyone | Safe | Anyone |
| General: Relationship | Couples | Safe | Anyone |
| General: Romantic | Everyone | Flirty | Anyone |
| General: Dirty | Couples | Explicit | Anyone |
| General: wording that points at one gender ("men in uniforms", "attracted to a woman") | Women or Men | as category | Anyone |
| General: cards in a man's voice ("my cologne") | Women | as category | A man's view |
| About You Two, Crazy Questions | Couples | Safe | Anyone |
| Conversation Topics | Women | Flirty | A man's view |
| Small Talk Upgrades | Everyone | Safe | Anyone |
| 21 Questions | Everyone | Safe | Anyone (the last card: Women, A man's view) |
| X-Rated level 1 | Couples | Flirty | Anyone |
| X-Rated levels 2 to 4 | Couples | Explicit | Anyone |
| Couple Cards: Conflicted, This or That, Curious | Couples (Curious: Everyone) | Safe | Anyone |
| Couple Cards: Cozy Up | Couples | Flirty | Anyone |
Words that signal sex or nudity raise a General card to Explicit; words that signal attraction or romance raise it to Flirty.

Features: `tests/library/card-audience/`, `tests/people/tag-people/`, `tests/library/custom-cards/custom-cards-v2.feature`.
