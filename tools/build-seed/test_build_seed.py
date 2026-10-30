import json
import unittest

from build_seed import build, only_decks

FIXTURE = """<html><body><article><div class="page-body">
<details open="" class="toggle"><summary>189 questions to ask your gf (general)</summary><div class="indented">
<ol class="numbered-list" start="1"><li>What is your favorite flower?</li></ol>
<ol class="numbered-list" start="2"><li>Romantic Questions To Ask Your Girlfriend</li></ol>
<ol class="numbered-list" start="3"><li>When was your first trip &amp; where?</li></ol>
<ol class="numbered-list" start="4"><li>Dirty questions</li></ol>
<ol class="numbered-list" start="5"><li>Cheeky one?</li></ol>
</div></details>
<details class="toggle"><summary>Questions to ask your gf (about you guys)</summary><div class="indented">
<ol class="numbered-list"><li>What do I do that you never get tired of?</li></ol></div></details>
<details class="toggle"><summary>those crazy questions that women ask (Ask them)</summary><div class="indented">
<ul class="bulleted-list"><li>If I were a goose, would you share your sandwich?</li></ul></div></details>
<details class="toggle"><summary>Conversation Topics that lead to sex</summary><div class="indented">
<p><strong>1. childhood stories.</strong></p><p>get them talking about when they were younger.</p><p></p>
<p><strong>2. &quot;what do you want?&quot;</strong></p><ul class="bulleted-list"><li><strong>Why it works:</strong> It shifts the vibe.</li></ul>
<p><strong>3. \u201cWhat is your green flag?\u201d</strong></p><ul class="bulleted-list"><li><strong>Why it works:</strong> Positive focus.</li></ul>
</div></details>
<details class="toggle"><summary>Ask questions like this (small talk me)</summary><div class="indented">
<p>\u274c \u201cWhat\u2019s new?\u201d<br/>\u2705 \u201cWhat\u2019s taking up your brain this week?\u201d</p>
<p>\u274c \u201cHow is work?\u201d<br/>\u2705 \u201cWhat project is interesting right now?\u201d</p>
</div></details>
<details class="toggle"><summary>21 questions to ask to collect details / nature</summary><div class="indented">
<p>1 \u2014 What kind of life would you build?</p>
<p>2 \u2014 What are you secretly proud of?</p>
<p>3 - Final one (use when the vibe is right): &quot;What kind of person do you respect?\u201d</p>
<p><strong>Values &amp; Character</strong></p>
<ul class="bulleted-list"><li>What boundary changed your life?</li></ul>
<ul class="bulleted-list"><li>What is something you used to <em>judge</em> others for?</li></ul>
<p><strong>Inner World</strong></p>
<ul class="bulleted-list"><li>How do you recharge?</li></ul>
</div></details>
<details class="toggle"><summary>X-Rated cards (couples cards)</summary><div class="indented">
<p><strong>Level 1: Tease</strong></p>
<ul class="bulleted-list"><li><strong>Slow dance</strong><p><em>no kissing until the song ends</em></p></li></ul>
<ul class="bulleted-list"><li><strong>Blindfold your partner</strong><p><em>guess where the kiss lands</em></p></li></ul>
<p><strong>Level 2: Touch</strong></p>
<ul class="bulleted-list"><li><strong>Give a massage</strong><p><em>take your time</em></p></li></ul>
</div></details>
<details class="toggle"><summary>Couple cards (know them better)</summary><div class="indented">
<p><strong>Conflicted</strong><em>Humorous ethical dilemmas.</em></p>
<ul class="bulleted-list"><li><strong>Card 1:</strong> You spot spinach in their teeth. Do you...
<ul class="bulleted-list"><li><strong>a.</strong> Tell them instantly.</li></ul>
<ul class="bulleted-list"><li><strong>b.</strong> Say nothing.</li></ul></li></ul>
<p><strong>This or That</strong><em>Fast choices.</em></p>
<ul class="bulleted-list"><li><strong>Card 1:</strong> Never text first <strong>OR</strong> never end a call first?</li></ul>
<p><strong>Curious</strong><em>Thoughtful.</em></p>
<ul class="bulleted-list"><li><strong>Card 1:</strong> What unwritten rule do you live by?</li></ul>
<p><strong>Cozy Up</strong><em>Playful.</em></p>
<ul class="bulleted-list"><li><strong>Card 1:</strong> Lock eyes for 30 seconds.</li></ul>
<p></p></div></details>
</div></article></body></html>"""


class BuildSeedTests(unittest.TestCase):
    def setUp(self):
        self.seed = build(FIXTURE)
        self.decks = {deck["id"]: deck for deck in self.seed["decks"]}

    def test_every_known_dropdown_becomes_a_deck_in_source_order(self):
        self.assertEqual(
            [deck["id"] for deck in self.seed["decks"]],
            ["general", "about-you-two", "crazy-questions", "conversation-topics",
             "small-talk-upgrades", "21-questions", "x-rated", "couple-cards"],
        )

    def test_general_headings_become_categories_and_are_not_cards(self):
        cards = self.decks["general"]["cards"]
        self.assertEqual(
            [(c["prompt"], c.get("category")) for c in cards],
            [("What is your favorite flower?", None),
             ("When was your first trip & where?", "Romantic"),
             ("Cheeky one?", "Dirty")],
        )

    def test_card_ids_are_stable_numbers_per_deck(self):
        self.assertEqual([c["id"] for c in self.decks["general"]["cards"]], ["general-001", "general-002", "general-003"])

    def test_plain_lists_become_questions(self):
        self.assertEqual(self.decks["about-you-two"]["cards"][0]["kind"], "question")
        self.assertEqual(self.decks["crazy-questions"]["cards"][0]["prompt"], "If I were a goose, would you share your sandwich?")

    def test_topics_keep_their_tip_text_and_lose_only_wrapping_quotes(self):
        cards = self.decks["conversation-topics"]["cards"]
        self.assertEqual(cards[0]["prompt"], "childhood stories.")
        self.assertEqual(cards[0]["detail"], "get them talking about when they were younger.")
        self.assertEqual(cards[1]["prompt"], "what do you want?")
        self.assertEqual(cards[1]["detail"], "Why it works: It shifts the vibe.")
        self.assertEqual(cards[2]["prompt"], "What is your green flag?")

    def test_small_talk_pairs_show_the_better_question_and_what_to_avoid(self):
        cards = self.decks["small-talk-upgrades"]["cards"]
        self.assertEqual(len(cards), 2)
        self.assertEqual(cards[0]["kind"], "upgrade")
        self.assertEqual(cards[0]["prompt"], "What\u2019s taking up your brain this week?")
        self.assertEqual(cards[0]["detail"], "Instead of: \u201cWhat\u2019s new?\u201d")

    def test_twenty_one_questions_include_the_final_card_and_the_themed_groups(self):
        cards = self.decks["21-questions"]["cards"]
        self.assertEqual(cards[0]["prompt"], "What kind of life would you build?")
        self.assertEqual(cards[2]["prompt"], "What kind of person do you respect?")
        self.assertEqual(cards[2]["detail"], "use when the vibe is right")
        self.assertEqual([(c["prompt"], c.get("category")) for c in cards[3:]], [
            ("What boundary changed your life?", "Values & Character"),
            ("What is something you used to judge others for?", "Values & Character"),
            ("How do you recharge?", "Inner World"),
        ])

    def test_x_rated_cards_are_dares_with_their_level(self):
        cards = self.decks["x-rated"]["cards"]
        self.assertEqual(len(cards), 3)
        self.assertEqual(cards[0], {"id": "x-rated-001", "kind": "dare", "prompt": "Slow dance",
                                    "category": "Level 1: Tease", "detail": "no kissing until the song ends"})
        self.assertEqual(cards[2]["category"], "Level 2: Touch")

    def test_couple_cards_keep_their_shape_per_group(self):
        cards = {c["category"]: c for c in self.decks["couple-cards"]["cards"]}
        self.assertEqual(cards["Conflicted"]["kind"], "multipleChoice")
        self.assertEqual(cards["Conflicted"]["prompt"], "You spot spinach in their teeth. Do you...")
        self.assertEqual(cards["Conflicted"]["options"], ["Tell them instantly.", "Say nothing."])
        self.assertEqual(cards["This or That"]["kind"], "thisOrThat")
        self.assertEqual(cards["This or That"]["options"], ["Never text first", "Never end a call first"])
        self.assertEqual(cards["Curious"]["kind"], "question")
        self.assertEqual(cards["Cozy Up"]["kind"], "dare")

    def test_output_is_valid_json_the_app_can_load(self):
        self.assertEqual(json.loads(json.dumps(self.seed, ensure_ascii=False))["version"], 1)

    def test_an_export_with_no_known_dropdowns_is_refused(self):
        with self.assertRaises(SystemExit):
            build("<html><body><details><summary>Something else</summary></details></body></html>")

    def test_only_keeps_the_chosen_decks_with_their_ids_unchanged(self):
        starter = only_decks(self.seed, ["21-questions"])
        self.assertEqual([deck["id"] for deck in starter["decks"]], ["21-questions"])
        self.assertEqual(starter["decks"][0]["cards"], self.decks["21-questions"]["cards"])

    def test_only_refuses_an_unknown_deck(self):
        with self.assertRaises(SystemExit):
            only_decks(self.seed, ["nope"])


if __name__ == "__main__":
    unittest.main()
