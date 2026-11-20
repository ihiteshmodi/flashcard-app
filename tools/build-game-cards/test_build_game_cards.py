import unittest

from build_game_cards import (blank_runs_standardised, build_set, clean_ocr_text, join_lines, review_notes,
                              settle_ocr_slips, share_picks)

RAW = {
    "black": [
        ["Coming soon!", "Batman vs.", "________________."],
        ["What really killed", "the dinosaurs?"],
        ["When I look in the", "mirror, I see", "."],
    ],
    "white": [["Ratzilla. "], ["Getting shot out", "of a cannon."]],
}


class JoinLinesTests(unittest.TestCase):
    def test_wrapped_lines_become_one_line_of_text(self):
        self.assertEqual(join_lines(["Getting shot out", "of a cannon."]), "Getting shot out of a cannon.")

    def test_stray_spaces_are_removed(self):
        self.assertEqual(join_lines(["Ratzilla. "]), "Ratzilla.")


class BlankTests(unittest.TestCase):
    def test_every_blank_is_written_the_same_length(self):
        self.assertEqual(blank_runs_standardised("Hey ___ and ________________!"), "Hey _____ and _____!")

    def test_text_without_a_blank_is_unchanged(self):
        self.assertEqual(blank_runs_standardised("What killed Old Jim?"), "What killed Old Jim?")


class OcrCleaningTests(unittest.TestCase):
    CASES = [
        ("apostrophes become curly", "Mom's spaghetti.", "Mom’s spaghetti.", False),
        ("a lowercase L before an apostrophe is an I", "l'm sorry.", "I’m sorry.", False),
        ("a lone bar is an I", "because | am hot dog.", "because I am hot dog.", False),
        ("straight quotes become curly", 'Saying "I love you."', "Saying “I love you.”", False),
        ("a blank is spaced from the word before it", "Do you see_____?", "Do you see _____?", True),
        ("a card ending in a blank ends with a full stop", "Dora explores _____", "Dora explores _____.", True),
        ("a bullet read for a full stop is a full stop", "Batman vs. _____•", "Batman vs. _____.", True),
        ("a closing quote read as 99 is a closing quote", "called “Rage Against _____. 99", "called “Rage Against _____.”", True),
        ("a full stop and closing quote read as 29", "They call me “Mr. _____29", "They call me “Mr. _____.”", True),
        ("a full stop found after the blank, then a closing quote read as 29", "me “Mr. _____.29", "me “Mr. _____.”", True),
        ("an opening quote glued to the word before the blank moves to the blank", "I’m” _____ Mandy.”", "I’m “_____ Mandy.”", True),
        ("an opening quote never closed is closed at the end", "It’s called “_____.", "It’s called “_____.”", True),
        ("a full stop before a closing quote is kept", "On the 12th day, me: _____.”", "On the 12th day, me: _____.”", True),
    ]

    def test_ocr_slips_are_cleaned(self):
        for name, raw, expected, black in self.CASES:
            with self.subTest(name):
                self.assertEqual(clean_ocr_text(raw, black=black), expected)


class BuildSetTests(unittest.TestCase):
    def build(self, fixes=None):
        default = {"When I look in the mirror, I see .": "When I look in the mirror, I see _____."}
        return build_set("family", "Family Edition", RAW, default if fixes is None else fixes)

    def test_a_set_has_the_id_and_title_given(self):
        built = self.build()

        self.assertEqual((built["id"], built["title"]), ("family", "Family Edition"))

    def test_cards_get_numbered_ids_in_page_order(self):
        built = self.build()

        self.assertEqual([c["id"] for c in built["black"]], ["family-b-001", "family-b-002", "family-b-003"])
        self.assertEqual([c["id"] for c in built["white"]], ["family-w-001", "family-w-002"])

    def test_black_card_text_has_standard_blanks(self):
        self.assertEqual(self.build()["black"][0]["text"], "Coming soon! Batman vs. _____.")

    def test_a_fix_replaces_the_text_the_pdf_lost_a_blank_from(self):
        self.assertEqual(self.build()["black"][2]["text"], "When I look in the mirror, I see _____.")

    def test_a_fix_that_matches_no_card_is_reported_so_a_changed_pdf_is_noticed(self):
        with self.assertRaises(ValueError):
            self.build({"When I look in the mirror, I see .": "When I look in the mirror, I see _____.", "Nothing like this card.": "x"})

    def test_a_black_card_that_lost_its_blank_and_has_no_fix_is_reported(self):
        with self.assertRaises(ValueError):
            self.build({})

    def test_white_card_text_is_kept_as_written(self):
        self.assertEqual([c["text"] for c in self.build()["white"]], ["Ratzilla.", "Getting shot out of a cannon."])

    def test_cards_read_by_ocr_are_cleaned(self):
        raw = {"black": [{"lines": ["Do you see_____?"]}], "white": [{"lines": ["Mom's spaghetti."]}]}

        built = build_set("uk", "UK", raw)

        self.assertEqual(built["black"][0]["text"], "Do you see _____?")
        self.assertEqual(built["white"][0]["text"], "Mom’s spaghetti.")

    def test_a_pick_the_blanks_do_not_show_is_kept(self):
        raw = {"black": [{"lines": ["Make a haiku about _____."], "pick": 3}, {"lines": ["_____ and _____."], "pick": 2}], "white": []}

        built = build_set("uk", "UK", raw)

        self.assertEqual(built["black"][0].get("pick"), 3)
        self.assertNotIn("pick", built["black"][1])

    def test_a_pick_badge_the_reader_flagged_as_unreadable_is_still_used(self):
        raw = {"black": [{"lines": ["Make a wish."], "flags": ["pick-unreadable: Cards Against Humanity PICK (3"]}], "white": []}

        self.assertEqual(build_set("can", "CAN", raw)["black"][0].get("pick"), 3)

    def test_the_blank_cards_to_write_on_are_not_cards(self):
        raw = {"black": [{"lines": ["Nice _____."]}, {"lines": []}], "white": [{"lines": []}, {"lines": ["Words."]}]}

        built = build_set("intl", "INTL", raw)

        self.assertEqual([c["id"] for c in built["black"]], ["intl-b-001"])
        self.assertEqual([c["text"] for c in built["white"]], ["Words."])

    def test_a_card_read_by_ocr_with_no_blank_is_left_for_review_not_refused(self):
        raw = {"black": [{"lines": ["Make a haiku."]}], "white": []}

        self.assertEqual(build_set("uk", "UK", raw)["black"][0]["text"], "Make a haiku.")


def card_set(set_id, *white_texts):
    return {"id": set_id, "title": set_id, "black": [],
            "white": [{"id": f"{set_id}-w-{n}", "text": text} for n, text in enumerate(white_texts, start=1)]}


class SettleOcrSlipsTests(unittest.TestCase):
    def texts(self, sets, set_id):
        return [c["text"] for c in next(s for s in sets if s["id"] == set_id)["white"]]

    def test_a_card_one_edit_from_a_card_in_two_sets_takes_that_cards_text(self):
        sets = [card_set("a", "Shut the fuck up."), card_set("b", "Shut the fuck up."), card_set("c", "Shut the fuck up,")]

        settle_ocr_slips(sets)

        self.assertEqual(self.texts(sets, "c"), ["Shut the fuck up."])

    def test_cards_that_differ_in_a_number_are_different_cards(self):
        sets = [card_set("a", "Barely making $25,000 a year."), card_set("b", "Barely making $25,000 a year."),
                card_set("c", "Barely making £15,000 a year.")]

        settle_ocr_slips(sets)

        self.assertEqual(self.texts(sets, "c"), ["Barely making £15,000 a year."])

    def test_a_card_close_to_a_card_in_only_one_other_set_is_left_alone(self):
        sets = [card_set("a", "A fuck-ton of almonds."), card_set("b", "A fuck-tonne of almonds.")]

        settle_ocr_slips(sets)

        self.assertEqual(self.texts(sets, "b"), ["A fuck-tonne of almonds."])

    def test_a_card_that_is_in_more_than_one_set_is_left_alone(self):
        sets = [card_set("a", "Shut up."), card_set("b", "Shut up."), card_set("c", "Shut up,"), card_set("d", "Shut up,")]

        settle_ocr_slips(sets)

        self.assertEqual(self.texts(sets, "c"), ["Shut up,"])


class SharePicksTests(unittest.TestCase):
    def black_set(self, set_id, **card):
        return {"id": set_id, "title": set_id, "white": [], "black": [{"id": f"{set_id}-b-1", "text": "Make a haiku.", **card}]}

    def test_a_card_with_a_pick_in_one_edition_has_it_in_every_edition(self):
        sets = [self.black_set("a", pick=3), self.black_set("b")]

        share_picks(sets)

        self.assertEqual(sets[1]["black"][0]["pick"], 3)


class ReviewNotesTests(unittest.TestCase):
    def test_words_the_dictionary_does_not_know_are_listed(self):
        raw = {"black": [], "white": [{"lines": ["Pokémon and fiames."]}]}

        notes = review_notes(build_set("uk", "UK", raw), words={"and"})

        self.assertEqual([n for n in notes if "unknown word" in n], ["uk-w-001: unknown word 'fiames' in 'Pokémon and fiames.'", "uk-w-001: unknown word 'pokémon' in 'Pokémon and fiames.'"])

    def test_a_black_card_with_no_blank_and_no_question_mark_is_listed(self):
        raw = {"black": [{"lines": ["Make a haiku."]}], "white": []}

        notes = review_notes(build_set("uk", "UK", raw), words={"make", "a", "haiku"})

        self.assertEqual(notes, ["uk-b-001: black card with no blank or question: 'Make a haiku.'"])


if __name__ == "__main__":
    unittest.main()
