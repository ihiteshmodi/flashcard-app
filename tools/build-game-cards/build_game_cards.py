#!/usr/bin/env python3
"""Builds the game-card JSON (sets of black and white cards) from raw card text read out of the print-and-play PDFs.

Usage: build_game_cards.py <out.json> --set ID "Title" raw.json [--set ...] [--fixes ID fixes.json ...]

raw.json is {"black": [[line, ...], ...], "white": [[line, ...], ...]} (see extract-text-cells.swift).
fixes.json maps a card's joined text, as read, to its corrected text. It is for cards whose blank is a drawn line
that the PDF has no text for. Every fix must match a card, so a changed PDF is noticed.
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


def build_set(set_id, title, raw, fixes=None):
    fixes = dict(fixes or {})
    unused = set(fixes)

    black = []
    for index, lines in enumerate(raw["black"], start=1):
        text = join_lines(lines)
        if text in fixes:
            unused.discard(text)
            text = fixes[text]
        elif "_" not in text and not text.endswith("?"):
            raise ValueError(f"black card has no blank and no fix: {text!r}")
        black.append({"id": f"{set_id}-b-{index:03d}", "text": blank_runs_standardised(text)})

    white = [
        {"id": f"{set_id}-w-{index:03d}", "text": join_lines(lines)}
        for index, lines in enumerate(raw["white"], start=1)
    ]

    if unused:
        raise ValueError(f"fixes that match no card: {sorted(unused)}")
    return {"id": set_id, "title": title, "black": black, "white": white}


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def main(arguments):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out")
    parser.add_argument("--set", nargs=3, action="append", metavar=("ID", "TITLE", "RAW"), required=True)
    parser.add_argument("--fixes", nargs=2, action="append", metavar=("ID", "FIXES"), default=[])
    options = parser.parse_args(arguments)

    fixes_by_set = {set_id: load(path) for set_id, path in options.fixes}
    sets = []
    for set_id, title, raw_path in options.set:
        built = build_set(set_id, title, load(raw_path), fixes_by_set.get(set_id))
        print(f"{title}: {len(built['black'])} black, {len(built['white'])} white")
        sets.append(built)
    with open(options.out, "w", encoding="utf-8") as handle:
        json.dump({"version": 1, "sets": sets}, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
