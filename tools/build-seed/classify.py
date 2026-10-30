"""Gives every bundled card its three labels: who it is for, how spicy, and whose point of view it is worded from.

The rules are the agreed default classification: by deck and category first, then by wording. A keyword can only
raise a card's spice, never lower it.
"""
import re

SPICE_ORDER = ["safe", "flirty", "explicit"]
EXPLICIT_WORDS = re.compile(
    r"\b(sex|sexual|naked|nude|orgasm\w*|oral|erotic\w*|porn\w*|masturbat\w*|fetish\w*|kink\w*|threesome|nipples?|"
    r"boobs?|breasts?|turn(s|ed)? you on)\b", re.I)
FLIRTY_WORDS = re.compile(
    r"\b(kiss\w*|attract\w*|crush\w*|sexy|flirt\w*|seduc\w*|make out|cuddl\w*|hit on|lingerie|bedroom|desire\w*|"
    r"romantic)\b", re.I)
GENDER_WORDS = re.compile(r"\b(woman|women|man|men)\b", re.I)
MANS_VOICE = re.compile(r"\b(cologne|beard)\b", re.I)
WORDED_BY_CATEGORY = {"Relationship": ("couples", "safe"), "Romantic": ("everyone", "flirty"), "Dirty": ("couples", "explicit")}
COUPLE_CARD_GROUPS = {
    "Conflicted": ("couples", "safe"), "This or That": ("couples", "safe"),
    "Curious": ("everyone", "safe"), "Cozy Up": ("couples", "flirty"),
}
DECKS_RAISED_BY_WORDING = ("general", "about-you-two", "crazy-questions")


def raised(spice, prompt):
    found = spice
    if FLIRTY_WORDS.search(prompt):
        found = max(found, "flirty", key=SPICE_ORDER.index)
    if EXPLICIT_WORDS.search(prompt):
        found = "explicit"
    return found


def classify(deck_id, entry):
    """Returns (audience, spice, perspective) for one card of a bundled deck."""
    prompt, category = entry["prompt"], entry.get("category")
    audience, spice, perspective = "everyone", "safe", "anyone"
    if deck_id == "general":
        audience, spice = WORDED_BY_CATEGORY.get(category, ("everyone", "safe"))
        if GENDER_WORDS.search(prompt) or MANS_VOICE.search(prompt):
            audience = "women"
        if MANS_VOICE.search(prompt):
            perspective = "man"
    elif deck_id in ("about-you-two", "crazy-questions"):
        audience = "couples"
    elif deck_id == "conversation-topics":
        audience, spice, perspective = "women", "flirty", "man"
    elif deck_id == "21-questions" and entry.get("detail"):
        audience, perspective = "women", "man"
    elif deck_id == "x-rated":
        audience, spice = "couples", "flirty" if (category or "").startswith("Level 1") else "explicit"
    elif deck_id == "couple-cards":
        audience, spice = COUPLE_CARD_GROUPS.get(category, ("everyone", "safe"))
    if deck_id in DECKS_RAISED_BY_WORDING:
        spice = raised(spice, prompt)
    return audience, spice, perspective
