#!/usr/bin/env python3
"""Builds the private seed JSON (decks and cards) from a Notion HTML export of conversation cards.

Usage: build_seed.py <export.html|export.zip> <seed.json>

Card text is copied exactly as written in the export; only HTML tags, entities and spacing are cleaned.
"""
import html
import json
import re
import sys
import zipfile
from pathlib import Path

TAG = re.compile(r"<[^>]+>")


def text(fragment):
    cleaned = re.sub(r"<br\s*/?>", " ", fragment)
    cleaned = html.unescape(TAG.sub("", cleaned))
    return re.sub(r"\s+", " ", cleaned).strip()


def strip_outer_quotes(value):
    if len(value) > 1 and value[0] in "\u201c\"" and value[-1] in "\u201d\"":
        return value[1:-1].strip()
    return value


def card(prompt, kind="question", category=None, detail=None, options=None):
    return {"category": category, "kind": kind, "prompt": prompt, "detail": detail, "options": options or []}


def list_items(segment):
    return [text(item) for item in re.findall(r"<li[^>]*>(.*?)</li>", segment, re.S)]


def extract_general(segment):
    heading = re.compile(r"^(.*?)\s+Questions To Ask Your Girlfriend$|^(Dirty) questions$", re.I)
    category, cards = None, []
    for item in list_items(segment):
        match = heading.match(item)
        if match:
            category = match.group(1) or match.group(2)
        elif item:
            cards.append(card(item, category=category))
    return cards


def extract_plain_list(segment):
    return [card(item) for item in list_items(segment) if item]


def extract_topics(segment):
    titles = list(re.finditer(r"<p[^>]*>\s*<strong>\s*(\d+)\.\s*(.*?)</strong>\s*</p>", segment, re.S))
    cards = []
    for index, match in enumerate(titles):
        end = titles[index + 1].start() if index + 1 < len(titles) else len(segment)
        detail = text(segment[match.end():end]) or None
        cards.append(card(strip_outer_quotes(text(match.group(2))), kind="topic", detail=detail))
    return cards


def extract_upgrades(segment):
    flat = text(segment)
    pairs = re.findall(r"\u274c\s*(.+?)\s*\u2705\s*(.+?)(?=\s*\u274c|\s*$)", flat, re.S)
    return [
        card(strip_outer_quotes(better), kind="upgrade", detail=f"Instead of: {boring}")
        for boring, better in pairs
    ]


def extract_twenty_one(segment):
    cards = []
    for paragraph in re.findall(r"<p[^>]*>(.*?)</p>", segment, re.S):
        line = text(paragraph)
        final = re.match(r"^\d+\s*[\u2014-]\s*Final one \((.*?)\):\s*(.+)$", line)
        numbered = re.match(r"^\d+\s*[\u2014-]\s*(.+)$", line)
        if final:
            cards.append(card(strip_outer_quotes(final.group(2)), detail=final.group(1)))
        elif numbered:
            cards.append(card(numbered.group(1)))
    token = re.compile(r"<p[^>]*>\s*<strong>([^<]+)</strong>\s*</p>|<li[^>]*>(.*?)</li>", re.S)
    category = None
    for match in token.finditer(segment):
        if match.group(1):
            category = text(match.group(1))
        elif category and text(match.group(2)):
            cards.append(card(text(match.group(2)), category=category))
    return cards


def extract_x_rated(segment):
    token = re.compile(
        r"<p[^>]*>\s*<strong>(Level[^<]+)</strong>\s*</p>"
        r"|<li[^>]*>\s*<strong>([^<]+)</strong>\s*<p[^>]*>\s*<em>([^<]+)</em>",
        re.S,
    )
    category, cards = None, []
    for match in token.finditer(segment):
        if match.group(1):
            category = text(match.group(1))
        else:
            cards.append(card(text(match.group(2)), kind="dare", category=category, detail=text(match.group(3))))
    return cards


def option_label(value):
    label = value.rstrip("?").strip()
    return label[:1].upper() + label[1:]


COUPLE_KINDS = {"Conflicted": "multipleChoice", "This or That": "thisOrThat", "Curious": "question", "Cozy Up": "dare"}


def extract_couple_cards(segment):
    parts = re.split(r"<p[^>]*>\s*<strong>([^<]+)</strong>\s*<em>[^<]*</em>", segment)
    cards = []
    for name, chunk in zip(parts[1::2], parts[2::2]):
        name = text(name)
        kind = COUPLE_KINDS.get(name, "question")
        for piece in re.split(r"<li[^>]*>\s*<strong>Card \d+:</strong>", chunk)[1:]:
            if kind == "multipleChoice":
                prompt = text(piece.split("<ul")[0])
                options = [text(o) for o in re.findall(r"<strong>[a-d]\.</strong>(.*?)</li>", piece, re.S)]
                cards.append(card(prompt, kind=kind, category=name, options=options))
            elif kind == "thisOrThat":
                sides = re.split(r"<strong>OR</strong>", piece.split("</li>")[0])
                first, second = text(sides[0]), text(sides[1])
                options = [option_label(first), option_label(second)]
                cards.append(card(f"{first} OR {second}", kind=kind, category=name, options=options))
            else:
                cards.append(card(text(piece.split("</li>")[0]), kind=kind, category=name))
    return cards


DECKS = [
    ("189 questions", "general", "General Questions", extract_general),
    ("about you guys", "about-you-two", "About You Two", extract_plain_list),
    ("crazy questions", "crazy-questions", "Crazy Questions", extract_plain_list),
    ("conversation topics", "conversation-topics", "Conversation Topics", extract_topics),
    ("ask questions like this", "small-talk-upgrades", "Small Talk Upgrades", extract_upgrades),
    ("21 questions", "21-questions", "21 Questions", extract_twenty_one),
    ("x-rated", "x-rated", "X-Rated", extract_x_rated),
    ("couple cards", "couple-cards", "Couple Cards", extract_couple_cards),
]


def read_export(path):
    path = Path(path)
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as archive:
            names = [n for n in archive.namelist() if n.lower().endswith(".html")]
            if not names:
                raise SystemExit("No .html file found in the zip")
            return archive.read(names[0]).decode("utf-8")
    return path.read_text(encoding="utf-8")


def build(source_html):
    body = source_html[source_html.find("<body"):]
    heads = list(re.finditer(r"<details[^>]*>\s*<summary>(.*?)</summary>", body, re.S))
    sections = {}
    for index, head in enumerate(heads):
        end = heads[index + 1].start() if index + 1 < len(heads) else len(body)
        sections[text(head.group(1))] = body[head.end():end]
    decks = []
    for needle, deck_id, title, extractor in DECKS:
        title_in_source = next((t for t in sections if needle in t.lower()), None)
        if title_in_source is None:
            continue
        cards = extractor(sections[title_in_source])
        for number, entry in enumerate(cards, start=1):
            entry["id"] = f"{deck_id}-{number:03d}"
        decks.append({"id": deck_id, "title": title, "cards": [compact(c) for c in cards]})
    if not decks:
        raise SystemExit("No known dropdowns found in the export")
    return {"version": 1, "decks": decks}


def compact(entry):
    ordered = {"id": entry["id"], "kind": entry["kind"], "prompt": entry["prompt"]}
    for key in ("category", "detail"):
        if entry[key]:
            ordered[key] = entry[key]
    if entry["options"]:
        ordered["options"] = entry["options"]
    return ordered


def main(argv):
    if len(argv) != 3:
        raise SystemExit(__doc__)
    seed = build(read_export(argv[1]))
    Path(argv[2]).parent.mkdir(parents=True, exist_ok=True)
    Path(argv[2]).write_text(json.dumps(seed, ensure_ascii=False, indent=1), encoding="utf-8")
    for deck in seed["decks"]:
        print(f"{deck['title']}: {len(deck['cards'])} cards")


if __name__ == "__main__":
    main(sys.argv)
