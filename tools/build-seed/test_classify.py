import unittest

from classify import classify


def card(prompt, category=None, kind="question", detail=None):
    return {"prompt": prompt, "category": category, "kind": kind, "detail": detail}


class ClassifyTests(unittest.TestCase):
    def labels(self, deck, **entry):
        return classify(deck, card(**entry))

    def test_plain_general_categories_are_for_everyone_and_safe(self):
        for category in (None, "Fun", "Cute", "Deep", "Random", "Personal"):
            self.assertEqual(self.labels("general", prompt="What is your favourite flower?", category=category),
                             ("everyone", "safe", "anyone"), category)

    def test_general_relationship_is_for_couples(self):
        self.assertEqual(self.labels("general", prompt="Where do we go next?", category="Relationship"),
                         ("couples", "safe", "anyone"))

    def test_general_romantic_is_flirty_and_dirty_is_explicit_for_couples(self):
        self.assertEqual(self.labels("general", prompt="Describe a perfect date.", category="Romantic"),
                         ("everyone", "flirty", "anyone"))
        self.assertEqual(self.labels("general", prompt="Describe your ideal evening.", category="Dirty"),
                         ("couples", "explicit", "anyone"))

    def test_words_about_sex_raise_a_card_to_explicit_and_attraction_to_flirty(self):
        self.assertEqual(self.labels("general", prompt="Have you ever had sex outdoors?", category="Fun")[1], "explicit")
        self.assertEqual(self.labels("general", prompt="Who was your first crush?", category="Personal")[1], "flirty")
        self.assertEqual(self.labels("general", prompt="Do you like to cuddle after a movie?", category="Cute")[1], "flirty")

    def test_a_keyword_never_lowers_a_card(self):
        self.assertEqual(self.labels("general", prompt="Tell me about your crush.", category="Dirty")[1], "explicit")

    def test_wording_that_points_at_one_gender_is_for_women_in_the_category_spice(self):
        self.assertEqual(self.labels("general", prompt="Do you like men in uniforms?", category="Dirty"),
                         ("women", "explicit", "anyone"))
        self.assertEqual(self.labels("general", prompt="What do you like most about being a woman?", category="Random"),
                         ("women", "safe", "anyone"))

    def test_a_card_in_a_mans_voice_is_worded_for_a_man(self):
        self.assertEqual(self.labels("general", prompt="Do you like it when I wear cologne?", category="Romantic"),
                         ("women", "flirty", "man"))

    def test_deck_defaults(self):
        self.assertEqual(self.labels("about-you-two", prompt="What do I do?"), ("couples", "safe", "anyone"))
        self.assertEqual(self.labels("crazy-questions", prompt="Goose?"), ("couples", "safe", "anyone"))
        self.assertEqual(self.labels("conversation-topics", prompt="childhood", kind="topic"), ("women", "flirty", "man"))
        self.assertEqual(self.labels("small-talk-upgrades", prompt="Better?", kind="upgrade"), ("everyone", "safe", "anyone"))

    def test_twenty_one_questions_are_open_except_the_final_card(self):
        self.assertEqual(self.labels("21-questions", prompt="What lesson?"), ("everyone", "safe", "anyone"))
        self.assertEqual(self.labels("21-questions", prompt="What kind of man do you respect?", detail="use when the vibe is right"),
                         ("women", "safe", "man"))

    def test_x_rated_level_one_is_flirty_and_deeper_levels_are_explicit(self):
        self.assertEqual(self.labels("x-rated", prompt="Slow dance", kind="dare", category="Level 1: Tease & Anticipation"),
                         ("couples", "flirty", "anyone"))
        for level in (2, 3, 4):
            self.assertEqual(self.labels("x-rated", prompt="Dare", kind="dare", category=f"Level {level}: Deeper"),
                             ("couples", "explicit", "anyone"))

    def test_couple_cards_by_group(self):
        expected = {"Conflicted": ("couples", "safe", "anyone"), "This or That": ("couples", "safe", "anyone"),
                    "Curious": ("everyone", "safe", "anyone"), "Cozy Up": ("couples", "flirty", "anyone")}
        for category, labels in expected.items():
            self.assertEqual(self.labels("couple-cards", prompt="Card", category=category), labels, category)

    def test_an_unknown_deck_is_for_everyone_and_safe(self):
        self.assertEqual(self.labels("something-new", prompt="Hello?"), ("everyone", "safe", "anyone"))


if __name__ == "__main__":
    unittest.main()
