#!/usr/bin/env python3
"""Builds the game-card JSON (sets of black and white cards) from raw card text read out of the print-and-play PDFs.

Usage: build_game_cards.py <out.json> --set ID "Title" raw.json [--set ...] [--fixes ID fixes.json ...] [--review notes.txt]

raw.json comes from extract-text-cells.swift ({"black": [[line, ...]], "white": [[line, ...]]}, exact text) or from
ocr-cards.swift ({"black": [{"lines": [...], "pick": 2}], ...}, read by OCR, so cleaned and listed for review).
fixes.json maps a card's text, as read and cleaned, to its corrected text. It is for cards the reader got wrong, such
as a blank that is a drawn line with no text behind it. Every fix must match a card, so a changed PDF is noticed.
--review writes the cards a person should still look at (words the dictionary does not know, odd black cards).
"""
import argparse
import json
import re
import sys

BLANK = re.compile(r"_+")


def join_lines(lines):
    return re.sub(r"\s+", " ", " ".join(lines)).strip()


def blank_runs_standardised(text):
    return BLANK.sub("_____", text)


def clean_ocr_text(text, black):
    """Puts right the slips OCR makes on these cards: quote marks, apostrophes, an I read as l or a bar, and the
    full stop after a drawn blank, which the reader does not see."""
    t = text.replace("•", ".")
    t = re.sub(r"(?<!\w)\|(?!\w)", "I", t)
    t = re.sub(r"\bl(?=['’](?:m|ve|ll|d)\b)", "I", t)
    t = t.replace("'", "’")
    if black:
        # The reader sees the quote marks around a blank as digits.
        t = re.sub(r"(?<!\w)66(?=\s*_)", "“", t)
        t = re.sub(r"(_+)\.?\s*29(?!\d)", r"\1.”", t)
        t = re.sub(r"(_+)(\.?)\s*(?:99|66)(?!\d)", r"\1\2”", t)
    quoted = []
    for index, character in enumerate(t):
        if character == '"':
            before = t[index - 1] if index else " "
            quoted.append("“" if before.isspace() or before in "(—" else "”")
        else:
            quoted.append(character)
    t = "".join(quoted)
    if black:
        t = re.sub(r"(\w)” (_+)", r"\1 “\2", t)
    t = re.sub(r"(?<![_\s“(])(_+)", r" \1", t)
    t = re.sub(r"(_+)(?=[A-Za-z])", r"\1 ", t)
    if black:
        t = re.sub(r"\s+([.,!?;:”])", r"\1", t)
    t = re.sub(r"\s+", " ", t).strip()
    if black:
        t = re.sub(r"(_+)$", r"\1.", t)
        t = re.sub(r"(_+)”$", r"\1.”", t)
        if t.count("“") > t.count("”"):
            t += "”"
    return t


def _written_on(entries):
    """The deck ends with blank cards to write on; they have no text and are not cards."""
    return [e for e in entries if join_lines(e["lines"] if isinstance(e, dict) else e)]


def _pick(entry):
    """The number on the PICK badge. The circled digit is often read as "(2", which the reader flags instead."""
    if entry.get("pick"):
        return entry["pick"]
    for flag in entry.get("flags", []):
        found = re.search(r"PICK\s*[(\[]?\s*(\d)", flag)
        if found:
            return int(found.group(1))
    return None


def build_set(set_id, title, raw, fixes=None):
    fixes = dict(fixes or {})
    unused = set(fixes)
    raw = {"black": _written_on(raw["black"]), "white": _written_on(raw["white"])}

    black = []
    for index, entry in enumerate(raw["black"], start=1):
        read_by_ocr = isinstance(entry, dict)
        text = join_lines(entry["lines"] if read_by_ocr else entry)
        if read_by_ocr:
            text = clean_ocr_text(text, black=True)
        if text in fixes:
            unused.discard(text)
            text = fixes[text]
        elif not read_by_ocr and "_" not in text and not text.endswith("?"):
            raise ValueError(f"black card has no blank and no fix: {text!r}")
        card = {"id": f"{set_id}-b-{index:03d}", "text": blank_runs_standardised(text)}
        pick = _pick(entry) if read_by_ocr else None
        if pick and pick != max(1, len(BLANK.findall(card["text"]))):
            card["pick"] = pick
        black.append(card)

    white = []
    for index, entry in enumerate(raw["white"], start=1):
        read_by_ocr = isinstance(entry, dict)
        text = join_lines(entry["lines"] if read_by_ocr else entry)
        if read_by_ocr:
            text = clean_ocr_text(text, black=False)
        if text in fixes:
            unused.discard(text)
            text = fixes[text]
        white.append({"id": f"{set_id}-w-{index:03d}", "text": text})

    if unused:
        raise ValueError(f"fixes that match no card: {sorted(unused)}")
    return {"id": set_id, "title": title, "black": black, "white": white}


def _edits(a, b, limit):
    """The number of single-character edits between two texts, or more than limit when they are further apart."""
    if abs(len(a) - len(b)) > limit:
        return limit + 1
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, start=1):
        row = [i]
        for j, cb in enumerate(b, start=1):
            row.append(min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (ca != cb)))
        previous = row
    return previous[-1]


def settle_ocr_slips(sets):
    """The editions repeat most cards, so a card seen in only one set that is a couple of characters away from a card
    seen in two or more sets is that card with an OCR slip. Cards that differ in a digit are different cards."""
    for kind in ("black", "white"):
        owners = {}
        for built in sets:
            for card in built[kind]:
                owners.setdefault(card["text"], set()).add(built["id"])
        common = [text for text, ids in owners.items() if len(ids) >= 2]
        for built in sets:
            for card in built[kind]:
                if len(owners[card["text"]]) != 1:
                    continue
                matches = [t for t in common
                           if _edits(card["text"].lower(), t.lower(), 2) <= 2
                           and re.findall(r"\d", card["text"]) == re.findall(r"\d", t)]
                if len(matches) == 1:
                    card["text"] = matches[0]


def share_picks(sets):
    """The badge is read in some editions and missed in others, but a card asks for the same number everywhere."""
    picks = {card["text"]: card["pick"] for built in sets for card in built["black"] if "pick" in card}
    for built in sets:
        for card in built["black"]:
            if "pick" not in card and card["text"] in picks:
                card["pick"] = picks[card["text"]]


WORD = re.compile(r"[^\W\d_]+(?:[’'][^\W\d_]+)*")


def _known(word, words):
    base = word.split("’")[0].split("'")[0]
    stems = {base, base[:-1], base[:-2], base[:-3], base[:-3] + "e", base[:-2] + "e", base[:-1] + "y"}
    return any(stem in words for stem in stems if len(stem) > 1) or len(base) < 2


def review_notes(built, words):
    """The cards a person should still look at, one line each."""
    notes = []
    for card in built["black"]:
        if "_" not in card["text"] and not card["text"].endswith("?"):
            notes.append(f"{card['id']}: black card with no blank or question: {card['text']!r}")
    for card in built["black"] + built["white"]:
        for word in sorted({w.lower() for w in WORD.findall(card["text"])}):
            if not _known(word, words):
                notes.append(f"{card['id']}: unknown word {word!r} in {card['text']!r}")
    return notes


def known_words(sets):
    """The dictionary plus every word that several different cards use, which a one-off OCR slip never does."""
    try:
        with open("/usr/share/dict/words", encoding="utf-8") as handle:
            words = {line.strip().lower() for line in handle}
    except OSError:
        words = set()
    uses = {}
    for built in sets:
        for card in built["black"] + built["white"]:
            for word in {w.lower() for w in WORD.findall(card["text"])}:
                uses[word] = uses.get(word, 0) + 1
    return words | {word for word, count in uses.items() if count >= 3}


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def main(arguments):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out")
    parser.add_argument("--set", nargs=3, action="append", metavar=("ID", "TITLE", "RAW"), required=True)
    parser.add_argument("--fixes", nargs=2, action="append", metavar=("ID", "FIXES"), default=[])
    parser.add_argument("--review", metavar="NOTES")
    options = parser.parse_args(arguments)

    fixes_by_set = {set_id: load(path) for set_id, path in options.fixes}
    sets = []
    for set_id, title, raw_path in options.set:
        built = build_set(set_id, title, load(raw_path), fixes_by_set.get(set_id))
        print(f"{title}: {len(built['black'])} black, {len(built['white'])} white")
        sets.append(built)
    settle_ocr_slips(sets)
    share_picks(sets)
    if options.review:
        words = known_words(sets)
        with open(options.review, "w", encoding="utf-8") as handle:
            handle.write("\n".join(note for built in sets for note in review_notes(built, words)) + "\n")
    with open(options.out, "w", encoding="utf-8") as handle:
        json.dump({"version": 1, "sets": sets}, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
