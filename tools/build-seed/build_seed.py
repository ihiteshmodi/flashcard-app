#!/usr/bin/env python3
"""Builds the private seed JSON (decks and cards) from a Notion HTML export of conversation cards.

Usage: build_seed.py <export.html|export.zip> <seed.json> [--only deck-id,deck-id]

Card text is copied exactly as written in the export; only HTML tags, entities and spacing are cleaned.
"""
import html
import json
import re
import sys
import zipfile
from pathlib import Path

from classify import classify

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


QUESTION_START = re.compile(
    r"^(What|Where|When|Who|Why|How|Which|Do|Does|Did|Have|Has|Is|Are|Was|Were|Would|Could|Can|Will|Should)\b"
)


def split_questions(prompt):
    """One flashcard holds one question: split a prompt only when each sentence stands on its own.

    A follow-up that needs the first sentence ("If yes, ...") or lists the options of the first
    question ("..., or ...") stays with it.
    """
    parts = [part.strip() for part in re.split(r"(?<=\?)\s+", prompt) if part.strip()]
    if len(parts) < 2:
        return [prompt]
    if not all(part.endswith("?") and QUESTION_START.match(part) for part in parts):
        return [prompt]
    if any(re.search(r"\bor\b", part) for part in parts[1:]):
        return [prompt]
    return parts


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
        cards = []
        for number, entry in enumerate(extractor(sections[title_in_source]), start=1):
            parts = split_questions(entry["prompt"]) if entry["kind"] == "question" else [entry["prompt"]]
            for index, part in enumerate(parts):
                suffix = "" if len(parts) == 1 else "abcdefghij"[index]
                labels = classify(deck_id, {**entry, "prompt": part})
                cards.append({**entry, "prompt": part, "id": f"{deck_id}-{number:03d}{suffix}",
                              "audience": labels[0], "spice": labels[1], "perspective": labels[2]})
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
    for key, default in (("audience", "everyone"), ("spice", "safe"), ("perspective", "anyone")):
        if entry[key] != default:
            ordered[key] = entry[key]
    return ordered


def only_decks(seed, deck_ids):
    wanted = set(deck_ids)
    decks = [deck for deck in seed["decks"] if deck["id"] in wanted]
    missing = wanted - {deck["id"] for deck in decks}
    if missing:
        raise SystemExit(f"Unknown deck id(s): {', '.join(sorted(missing))}")
    return {**seed, "decks": decks}


def main(argv):
    args = argv[1:]
    only = None
    if "--only" in args:
        position = args.index("--only")
        if position + 1 >= len(args):
            raise SystemExit(__doc__)
        only = args[position + 1].split(",")
        del args[position:position + 2]
    if len(args) != 2:
        raise SystemExit(__doc__)
    seed = build(read_export(args[0]))
    if only:
        seed = only_decks(seed, only)
    Path(args[1]).parent.mkdir(parents=True, exist_ok=True)
    Path(args[1]).write_text(json.dumps(seed, ensure_ascii=False, indent=1), encoding="utf-8")
    for deck in seed["decks"]:
        print(f"{deck['title']}: {len(deck['cards'])} cards")


if __name__ == "__main__":
    main(sys.argv)
