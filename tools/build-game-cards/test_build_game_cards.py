import unittest

from build_game_cards import blank_runs_standardised, build_set, join_lines

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


if __name__ == "__main__":
    unittest.main()
