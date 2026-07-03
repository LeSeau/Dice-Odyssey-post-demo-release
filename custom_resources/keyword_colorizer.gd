class_name KeywordColorizer
extends RefCounted

# Shared by Card.get_colorized_description() and Relic.get_colorized_description() - both
# resources have their own `tags` string field (comma-separated, e.g. "Charge, Blessed") that
# the hover-tooltip system already reads (tooltip.gd::get_tooltip_content(), card_ui.gd/
# relic_ui.gd's hover handlers), so this was pulled out here rather than duplicated once a
# second real consumer (relics) needed the exact same keyword/color/regex logic as cards.

# One consistent highlight color for every keyword in a description - matches the reference
# (Slay the Spire 2) approach: keyword TEXT stays a single accent color, rather than a
# color-per-keyword rainbow. STS2 differentiates specific resources via distinct inline ICONS
# instead (e.g. "Gain [sun icon]" vs "Gain [gem icon]", same text color) - this project doesn't
# have per-keyword icon art yet, so that per-resource distinction is simply not made today; a
# single accent color avoids the "rainbow soup" a color-per-keyword approach risked on cards
# tagging several different keywords at once. Reuses the same gold already used elsewhere for
# "important" accents (tooltip title, Card.RARITY_COLORS' Support entry).
const KEYWORD_HIGHLIGHT_COLOR := "FFD700"

# Recognized keywords eligible for highlighting - mirrors the same tag strings the hover-tooltip
# system already reads in tooltip.gd::get_tooltip_content(), so tagging a card/relic for
# tooltip purposes also makes it eligible for colorized keywords, with no separate bookkeeping.
const KEYWORDS: Array[String] = [
    "Charge", "Refuel", "Scout", "Boost", "Blessed", "Weak", "Exposed", "Lucky", "Unlucky",
    "Depleted", "Energized", "Strength", "Muscle", "Exhaust", "Support", "REST",
    "Blue Dice", "Red Dice", "Green Dice", "Odd Dice", "Even Dice", "Evil Dice",
    "Giant Dice", "Magma Dice", "Mech Dice",
]

# Checked every card description in characters/warrior/cards/ and every relic tooltip in
# relics/: every keyword above is written as "Keyword N" (Charge 1, Boost 4, Scout 3, Weak 1,
# Depleted 1, Blessed 1...) with exactly one exception - Strength/Muscle is written as
# "N Strength" (e.g. card Bolster: "Gain 2 Strength", relic Sledgehammer: "gain 1 strength"),
# the number BEFORE the word instead of after. colorize() below picks which side to grab the
# adjacent number from based on this list, so "Gain 2 Strength" highlights as one unit instead
# of leaving "Strength" colored and "2" plain (or worse, in "Charge 3 Blue Dice" cards,
# incorrectly grabbing Charge's own "3" into a trailing match on "Blue Dice" instead).
const LEADING_NUMBER_KEYWORDS: Array[String] = ["Strength", "Muscle"]

# Exception to the single-color rule above: dice-type mentions get tinted with that die's own
# established color instead of the shared gold. Unlike the other keywords, these colors aren't
# arbitrary - they're the same ones the dice already wear everywhere else in the game (aura glow
# in dice.gd, the power-orb particles), so tinting "Blue Dice" blue reinforces an association the
# player already has rather than inventing a new one. Values match dice.gd's
# _get_power_orb_color() for the same 9 types.
const DICE_KEYWORD_COLORS := {
    "Blue Dice": "5A8BFF",
    "Red Dice": "FF3322",
    "Green Dice": "33FF99",
    "Odd Dice": "FFD60B",
    "Even Dice": "FFAA55",
    "Evil Dice": "DD55DD",
    "Giant Dice": "99FF55",
    "Magma Dice": "FF5522",
    "Mech Dice": "BBBBBB",
}

# Single source of truth for "what does this dice type actually do", keyed by the same "X Dice"
# strings as DICE_KEYWORD_COLORS above. Used by both tooltip.gd (card/relic hover tooltips,
# keyed directly by these strings) and dice_tooltip.gd (the dice-shop hover tooltip, keyed by
# lowercase type names like "even" - builds the same "X Dice" key via .capitalize()). This is
# the original "Faces: ..." wording that already existed in dice_tooltip.gd - the dice name
# itself isn't repeated in the body text since both tooltip panels already show it as the title.
const DICE_TOOLTIP_TEXT := {
    "Blue Dice": "Faces: 1-6",
    "Red Dice": "Faces: 1-6. Select a card before rolling the Dice.",
    "Green Dice": "Faces: 1-3",
    "Odd Dice": "Faces: 1, 3, 5, 7",
    "Even Dice": "Faces: 2, 4, 6, 8",
    "Evil Dice": "Faces: 6, 6, 6, 0",
    "Giant Dice": "Faces: 1-12",
    "Magma Dice": "Faces: 1-6. Deals X damage to ALL enemies every roll.",
    "Mech Dice": "Faces: 1-6. After each roll, you can add or substract 1 Power.",
}


# Wraps every keyword from `tags` (e.g. "Charge, Blessed") that appears in `text` with a BBCode
# [color] tag. Data-driven off the same `tags` field the hover-tooltip system reads - tagging a
# card/relic for tooltip purposes automatically makes it eligible for colorized keywords too, no
# per-card/per-relic wiring needed beyond that existing string.
#
# Dice-type keywords are the one exception - they're ALWAYS checked regardless of `tags` (see
# below), rather than requiring an explicit tag like every other keyword does. Found the reason
# while auditing why "Blue Dice"/"Even Dice"/"Giant Dice" weren't coloring on several shop cards
# and the Dice Bag relic: tooltip.gd::get_tooltip_content() only ever had real tooltip text for
# 4 of the 9 dice types (Green/Magma/Giant/Evil), so authors only bothered tagging THOSE on cards
# - Blue/Red/Odd/Even/Mech mentions were never tagged at all (Dice Bag's `tags` is even empty
# outright), since tagging them wouldn't have shown a tooltip anyway under the old system. A
# literal dice-type name has essentially no false-positive risk in this game's mechanical
# descriptions (unlike "Charge"/"Boost" etc., which do need the tag as a real gate), so it's
# safe to just always look for them instead of depending on tag data that was never populated.
#
# Note: if `tags` contains a keyword that's a substring of another tagged keyword (e.g. both
# "Strength" and "True Strength"), the shorter one can still match a second time inside the
# longer one's already-wrapped span - harmless now that every keyword shares one color (just a
# redundant nested [color] tag, not a visible glitch), but sorting longest-first still avoids
# even that redundancy in the common case.
static func colorize(text: String, tags: String) -> String:
    var keywords: Array[String] = []
    for dice_keyword in DICE_KEYWORD_COLORS:
        keywords.append(dice_keyword)

    if not tags.is_empty():
        for raw_tag in tags.split(","):
            var keyword := raw_tag.strip_edges()
            if keyword != "" and KEYWORDS.has(keyword) and not keywords.has(keyword):
                keywords.append(keyword)

    keywords.sort_custom(func(a, b): return a.length() > b.length())

    var result := _put_exhaust_on_own_line(text)
    for keyword in keywords:
        var regex := RegEx.new()
        # Whole-word, case-insensitive - $0 in the replacement preserves whatever casing the
        # text actually used (e.g. mid-sentence lowercase "charge") instead of forcing the
        # tag's own casing onto every match. Also grabs one adjacent number (see
        # LEADING_NUMBER_KEYWORDS above for which side), so "Scout 3"/"Boost 4"/"Gain 2
        # Strength" highlight as a single unit instead of leaving the number in plain text.
        if LEADING_NUMBER_KEYWORDS.has(keyword):
            regex.compile("(?i)(\\d+\\s+)?\\b" + keyword + "\\b")
        else:
            regex.compile("(?i)\\b" + keyword + "\\b(\\s*\\d+)?")
        var color: String = DICE_KEYWORD_COLORS.get(keyword, KEYWORD_HIGHLIGHT_COLOR)
        result = regex.sub(result, "[color=#%s]$0[/color]" % color, true)
    return result


# Which dice-type keywords are literally present in `text`, regardless of tags - used to make
# the hover-tooltip system (card_ui.gd/relic_ui.gd's mouse_entered handlers) show a dice-type
# explanation even when the card/relic was never explicitly tagged with it, for the same reason
# colorize() above doesn't gate dice-type coloring on tags: dice-type tags were historically
# only added for the 4 types tooltip.gd used to explain (Green/Magma/Giant/Evil), so Blue/Red/
# Odd/Even/Mech mentions never got tagged and their tooltips never showed.
static func find_dice_keywords_in_text(text: String) -> Array[String]:
    var found: Array[String] = []
    for dice_keyword in DICE_KEYWORD_COLORS:
        var regex := RegEx.new()
        regex.compile("(?i)\\b" + dice_keyword + "\\b")
        if regex.search(text):
            found.append(dice_keyword)
    return found


# STS2-style: "Exhaust" reads as a standalone reminder line rather than trailing prose - push it
# onto its own line when it appears as a suffix ("Deal X damage. Exhaust" -> "Deal X damage.\n
# Exhaust"), keeping the period, just swapping the preceding space for a line break. A couple of
# cards (Exhaust Oracle, Scout+2) instead lead with "Exhaust: Scout 3" - skipped here since
# Exhaust is the very first word there, with nothing before it on that line to split away from.
# Relics don't currently use "Exhaust" at all, so this is a no-op for them - kept here anyway
# since it's part of the same shared text-shaping pass, not worth a separate call site.
static func _put_exhaust_on_own_line(text: String) -> String:
    var idx := text.find("Exhaust")
    if idx <= 0:
        return text
    if idx + 7 < text.length() and text[idx + 7] == ":":
        return text
    if text[idx - 1] == " ":
        return text.substr(0, idx - 1) + "\n" + text.substr(idx)
    return text
