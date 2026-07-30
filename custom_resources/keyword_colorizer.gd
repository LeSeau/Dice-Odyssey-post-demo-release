class_name KeywordColorizer
extends RefCounted

# Shared by Card.get_colorized_description() and Relic.get_colorized_description() - both
# resources have their own `tags` string field (comma-separated, e.g. "Charge, Infused") that
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

# --- Power glyph (2026-07-29) ---
# The Power resource gets an inline icon in card/relic text: the standalone "X" placeholder
# ("Deal X damage", "Block X2") always renders as the glyph, and the word "Power" renders
# according to power_glyph_mode below. The glyph asset is near-monochrome warm gold so it can
# be [img color=...]-tinted later without regenerating art.
# NOTE: this happens at colorize() time, NEVER in the .tres descriptions themselves -
# card_ui/card_menu_ui measure the RAW description length for their font step-down BEFORE
# colorizing, so BBCode injected here doesn't skew that measurement (verified in-engine).
const POWER_GLYPH_PATH := "res://power_glyph.png"

enum PowerGlyphMode {
    OFF,               # plain text, pre-glyph behavior
    WORD_WITH_GLYPH,   # "your Power" -> "your [glyph] Power" (gold word) - teaching mode
    GLYPH_ONLY,        # "your Power" -> "your [glyph]" - full symbol mode (MTG-style)
}
# static var (not const) so harnesses can flip modes at runtime for side-by-side renders.
static var power_glyph_mode := PowerGlyphMode.WORD_WITH_GLYPH

# Recognized keywords eligible for highlighting - mirrors the same tag strings the hover-tooltip
# system already reads in tooltip.gd::get_tooltip_content(), so tagging a card/relic for
# tooltip purposes also makes it eligible for colorized keywords, with no separate bookkeeping.
const KEYWORDS: Array[String] = [
    "Charge", "Refuel", "Scout", "Boost", "Throw", "Infused", "Weak", "Exposed", "Lucky",
    "Unlucky", "Depleted", "Energized", "Strength", "Muscle", "Exhaust", "Support", "REST",
    "Blue Dice", "Red Dice", "Pixie Dice", "Odd Dice", "Even Dice", "Evil Dice",
    "Giant Dice", "Magma Dice", "Mech Dice",
]

# Checked every card description in characters/warrior/cards/ and every relic tooltip in
# relics/: every keyword above is written as "Keyword N" (Charge 1, Boost 4, Scout 3, Weak 1,
# Depleted 1, Infused 1...) with exactly one exception - Strength/Muscle is written as
# "N Strength" (e.g. card Bolster: "Gain 2 Strength", relic Sledgehammer: "gain 1 strength"),
# the number BEFORE the word instead of after. colorize() below picks which side to grab the
# adjacent number from based on this list, so "Gain 2 Strength" highlights as one unit instead
# of leaving "Strength" colored and "2" plain (or worse, in "Charge 3 Blue Dice" cards,
# incorrectly grabbing Charge's own "3" into a trailing match on "Blue Dice" instead).
const LEADING_NUMBER_KEYWORDS: Array[String] = ["Strength", "Muscle"]

# U+00A0. The description label wraps on AUTOWRAP_WORD, which breaks at any ordinary space - so
# "Charge 2" could land as "Charge" / "2" on two lines, and the Power glyph could be stranded on
# the line above its own word ("does not reset your [glyph]" / "Power."). Both looked broken in
# game (Julien, 2026-07-29). A non-breaking space is the only lever here: Godot has no BBCode
# "nobr", and TextServer honours UAX #14, which forbids a break at U+00A0. Used ONLY for tight
# 2-token pairs - binding longer phrases would create unbreakable runs wider than the 128px
# column, which AUTOWRAP_WORD cannot split and would overflow instead.
const NBSP := " "

# Exception to the single-color rule above: dice-type mentions get tinted with that die's own
# established color instead of the shared gold. Unlike the other keywords, these colors aren't
# arbitrary - they're the same ones the dice already wear everywhere else in the game (aura glow
# in dice.gd, the power-orb particles), so tinting "Blue Dice" blue reinforces an association the
# player already has rather than inventing a new one. Kept in sync BY HAND with
# DicePalette.ACCENT (custom_resources/dice_palette.gd) - a const dict needs literal hex
# strings for the BBCode tags, so it can't read the palette's Color values. Update both together.
const DICE_KEYWORD_COLORS := {
    "Blue Dice": "3D7BFF",
    "Red Dice": "FF2F3E",
    "Pixie Dice": "48D147",
    "Odd Dice": "E9B83D",
    "Even Dice": "FF9526",
    "Evil Dice": "E14FE1",
    "Giant Dice": "A9D648",
    "Magma Dice": "FF5A14",
    "Mech Dice": "B9C1CB",
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
    "Pixie Dice": "Faces: 1-3",
    "Odd Dice": "Faces: 1, 3, 5, 7",
    "Even Dice": "Faces: 2, 4, 6, 8",
    "Evil Dice": "Faces: 6, 6, 6, 0",
    "Giant Dice": "Faces: 1-12",
    "Magma Dice": "Faces: 1-6. Deals X damage to ALL enemies every roll.",
    "Mech Dice": "Faces: 1-6. After each roll, you can add or subtract 1 Power.",
}

# Type-string -> display-name overrides, for the rare case where the internal Global.dice_type
# string doesn't match the player-facing name. Added when "Green Dice" was renamed to "Pixie
# Dice" (2026-07-16) WITHOUT touching the internal "green" string - that's baked into ~9 Global
# variable trios (green_dice_current/max/bonus_amount), save data, the green dice shader, and
# green1-3.png texture filenames, so renaming it would be a much bigger/riskier sweep for a
# display-only change. dice_display_name() is the one place that still needs to turn a raw type
# string into its shown name (dice_tooltip.gd's shop/battle hover tooltip title) - every other
# consumer already reads the literal "Pixie Dice" string straight out of a card/relic's own text.
const DICE_TYPE_DISPLAY_NAME_OVERRIDES := {
    "green": "Pixie",
}


static func dice_display_name(dice_type: String) -> String:
    return DICE_TYPE_DISPLAY_NAME_OVERRIDES.get(dice_type, dice_type.capitalize())


# Wraps every keyword from `tags` (e.g. "Charge, Infused") that appears in `text` with a BBCode
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
static func colorize(text: String, tags: String, glyph_px: int = 16) -> String:
    var other_keywords: Array[String] = []
    if not tags.is_empty():
        for raw_tag in tags.split(","):
            var keyword := raw_tag.strip_edges()
            if keyword != "" and KEYWORDS.has(keyword) and not DICE_KEYWORD_COLORS.has(keyword):
                other_keywords.append(keyword)
    other_keywords.sort_custom(func(a, b): return a.length() > b.length())

    var result := _put_exhaust_on_own_line(text)

    # 1. Dice-type keywords go FIRST, and always grab a leading number ("1 Giant Dice" as one
    # unit) - this groups the number with the die being referenced ("charge ONE Giant die")
    # rather than with the preceding verb.
    for keyword in DICE_KEYWORD_COLORS:
        var regex := RegEx.new()
        regex.compile("(?i)(\\d+\\s+)?\\b" + keyword + "\\b")
        result = regex.sub(result, "[color=#%s]$0[/color]" % DICE_KEYWORD_COLORS[keyword], true)

    # 2. If a generic keyword (Charge, Boost...) sits directly before a dice mention just
    # colored above, pull it INTO that same [color] tag rather than giving it its own separate
    # gold span - "Charge 2 Magma Dice" reads as one solid color instead of a two-tone split in
    # such a short phrase (requested by Julien). This purely reorders text already produced by
    # step 1: "Charge [color=#X]2 Magma Dice[/color]" becomes "[color=#X]Charge 2 Magma Dice[/color]".
    for keyword in other_keywords:
        var absorb_regex := RegEx.new()
        absorb_regex.compile("(?i)\\b(" + keyword + ")(\\s+)(\\[color=#[0-9A-Fa-f]{6}\\])")
        # NBSP instead of the captured $2: keeps "Charge" welded to the count that follows it
        # ("Charge 2 Magma Dice" can still break before "Magma", never before "2").
        result = absorb_regex.sub(result, "$3$1" + NBSP, true)

    # 3. Whatever's left of each keyword (i.e. NOT already absorbed into a dice color in step 2)
    # gets the shared gold. The negative lookbehind skips a keyword that's already inside a
    # [color] tag from step 2 - without it, "Charge" would get wrapped in gold a SECOND time,
    # nested inside the dice's [color] tag, and the inner tag would win, turning it gold again
    # instead of staying the dice color. $0 in the replacement preserves whatever casing the
    # text actually used (e.g. mid-sentence lowercase "charge") instead of forcing the tag's
    # own casing onto every match. Also grabs one adjacent number (see LEADING_NUMBER_KEYWORDS
    # above for which side), so "Scout 3"/"Boost 4"/"Gain 2 Strength" highlight as a single unit
    # instead of leaving the number in plain text.
    for keyword in other_keywords:
        var pattern := ""
        if LEADING_NUMBER_KEYWORDS.has(keyword):
            pattern = "(?i)(?<!\\[color=#[0-9A-Fa-f]{6}\\])(\\d+\\s+)?\\b" + keyword + "\\b"
        else:
            pattern = "(?i)(?<!\\[color=#[0-9A-Fa-f]{6}\\])\\b" + keyword + "\\b(\\s*\\d+)?"
        result = _wrap_keyword_span(result, pattern, KEYWORD_HIGHLIGHT_COLOR)

    # 4. Power glyph, LAST so it can't disturb the [color] spans built above ("X" and "Power"
    # are not KEYWORDS, so steps 1-3 never touch them; and the glyph path is lowercase, so
    # neither regex here can re-match inside the [img] tags it inserts).
    if power_glyph_mode != PowerGlyphMode.OFF:
        result = _apply_power_glyph(result, glyph_px)

    # 5. Resolved-value parens from dynamic descriptions ("Deal X3 damage (9)") pop in gold.
    # Matches ONLY a pure number (or the Ink "?") between parens - formula parentheticals
    # like "(3, plus 3 per card...)" contain words/punctuation and are deliberately left
    # alone (audited: no static description contains a bare numeric paren).
    var value_regex := RegEx.new()
    value_regex.compile("\\((\\d+|\\?)\\)")
    result = value_regex.sub(result, "[color=#%s]($1)[/color]" % KEYWORD_HIGHLIGHT_COLOR, true)
    return result


# Wraps every match of `pattern` in a [color] span, with any space INSIDE the match turned into a
# NBSP so a keyword can never be split from the number it owns ("Charge 2", "2 Strength"). Built by
# hand rather than with RegEx.sub("[color=..]$0[/color]") because Godot's replacement strings can
# substitute a capture but can't transform one. Safe to blanket-replace every space in the match:
# the only spaces a keyword span can contain are the keyword/number gap (all non-dice KEYWORDS are
# single words - the multi-word ones, "Blue Dice" etc., are handled by the dice pass instead).
static func _wrap_keyword_span(text: String, pattern: String, color: String) -> String:
    var regex := RegEx.new()
    regex.compile(pattern)
    var result := ""
    var last := 0
    for m in regex.search_all(text):
        result += text.substr(last, m.get_start() - last)
        result += "[color=#%s]%s[/color]" % [color, m.get_string(0).replace(" ", NBSP)]
        last = m.get_end()
    result += text.substr(last)
    return result


# Standalone uppercase "X" (with optional multiplier digits: "X2".."X12") -> inline glyph;
# "X3" becomes "[glyph]x3" so the multiplier finally reads unambiguously as "times 3".
# Case-sensitive on purpose: lowercase x (Exhaust, exact...) must never match.
# The word "Power" then renders per power_glyph_mode. Dynamic descriptions that already
# resolved X to a number simply have no X left to match - the glyph shows only while the
# amount is unknown, which is exactly the placeholder's job.
static func _apply_power_glyph(text: String, glyph_px: int) -> String:
    var img := power_glyph_img(glyph_px)
    var result := _swap_x_placeholder(text, glyph_px)

    var re_p := RegEx.new()
    re_p.compile("\\bPower\\b")
    if power_glyph_mode == PowerGlyphMode.GLYPH_ONLY:
        result = re_p.sub(result, img, true)
    else:
        # NBSP, never a plain space: the glyph must never be stranded at the end of a line with
        # its own word wrapped to the next one (Julien's rule - the icon always sits beside Power).
        result = re_p.sub(result, "%s%s[color=#%s]Power[/color]" % [
            img, NBSP, KEYWORD_HIGHLIGHT_COLOR], true)
    return result


# The inline BBCode for one glyph. Shared so nothing else has to hardcode the [img] form or
# the asset path.
static func power_glyph_img(glyph_px: int) -> String:
    return "[img=%d]%s[/img]" % [glyph_px, POWER_GLYPH_PATH]


# The X half of the glyph pass, split out because authored text (below) wants it too.
static func _swap_x_placeholder(text: String, glyph_px: int) -> String:
    var img := power_glyph_img(glyph_px)
    var re_x := RegEx.new()
    re_x.compile("\\bX(\\d*)\\b")
    var result := ""
    var last := 0
    for m in re_x.search_all(text):
        result += text.substr(last, m.get_start() - last)
        result += img
        if m.get_string(1) != "":
            # Proper multiplication sign, not the letter x - "[glyph]×3" reads as arithmetic
            # where "[glyph]x3" read like a stray variable (Julien's call, 2026-07-29).
            result += "×%s" % m.get_string(1)
        last = m.get_end()
    result += text.substr(last)
    return result


# Glyph pass for text that was ALREADY hand-authored with BBCode - i.e. the tutorial's boxes,
# which carry their own colour language ([color=red]Power[/color], gold numbers, purple Cards).
# Unlike colorize()'s pass 4 this only INSERTS the glyph and recolours nothing, so the author's
# markup survives untouched; and when the word already sits inside a [color] span the glyph is
# placed BEFORE the opening tag, so it keeps its own warm gold instead of reading as part of
# that span. The word itself is always kept (GLYPH_ONLY included, unlike card text): the
# tutorial is the one surface whose entire job is binding the glyph TO the word, so it has to
# show both no matter which wording mode ships.
# Not idempotent by regex, hence the early-out: hand it the raw authored string, not a string
# this already returned (overlay call sites keep the raw copy for re-layout for that reason).
static func add_power_glyph_to_authored_text(text: String, glyph_px: int) -> String:
    if power_glyph_mode == PowerGlyphMode.OFF or text.contains(POWER_GLYPH_PATH):
        return text
    var result := _swap_x_placeholder(text, glyph_px)
    var re_p := RegEx.new()
    re_p.compile("(\\[color=[^\\]]+\\])?\\bPower\\b")
    return re_p.sub(result, "%s $0" % power_glyph_img(glyph_px), true)


# Whether `text` will render the Power glyph - the word "Power" or the standalone X
# placeholder (same case-sensitive patterns _apply_power_glyph() swaps). Used by the card
# hover handlers to show the "Power" tooltip without any tag bookkeeping, mirroring how
# dice-type tooltips are detected from text below.
static func text_mentions_power(text: String) -> bool:
    if power_glyph_mode == PowerGlyphMode.OFF:
        return false
    return _power_mention_position(text) >= 0


# First character index of a Power mention, or -1. Split out so the tooltip ordering below can
# place "Power" by where it actually reads rather than always last.
static func _power_mention_position(text: String) -> int:
    var regex := RegEx.new()
    regex.compile("\\bPower\\b|\\bX\\d*\\b")
    var m := regex.search(text)
    return m.get_start() if m else -1


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


# Every hover-tooltip keyword a card's text earns, ORDERED BY WHERE IT READS. A player scans a
# card top-down, so the tooltip stack should follow the sentence - not the order the author
# happened to type `tags`, not DICE_KEYWORD_COLORS' dict order, and not "Power always last"
# (all three of which the two hover handlers used to do independently).
# Sources are the same three as before, so which tooltips appear is unchanged: every tag, plus
# dice types found in the description, plus Power. Only the ORDER changes.
# Position falls back from description -> bonus-effect line -> nothing. A tag matching neither
# is granted by script without the card ever printing the word (Gang Up tags Infused but its
# text never says it), so there is nothing on the card to read it next to: those trail the
# readable ones, keeping their authored order.
static func ordered_description_keywords(
        description: String, tags: String, bonus_text: String = "") -> Array[String]:
    var candidates: Array[String] = []
    if not tags.is_empty():
        for raw_tag in tags.split(","):
            var tag := raw_tag.strip_edges()
            if tag != "" and not candidates.has(tag):
                candidates.append(tag)
    for dice_keyword in find_dice_keywords_in_text(description):
        if not candidates.has(dice_keyword):
            candidates.append(dice_keyword)
    if text_mentions_power(description) and not candidates.has("Power"):
        candidates.append("Power")

    # Sorted on (position, original index): Array.sort_custom is not documented as stable, so
    # the tiebreak is explicit - it keeps authored order among the unpositioned trailers.
    var ranked: Array = []
    for i in candidates.size():
        ranked.append({"name": candidates[i], "pos": _keyword_position(
            candidates[i], description, bonus_text), "idx": i})
    ranked.sort_custom(func(a, b):
        if a["pos"] != b["pos"]:
            return a["pos"] < b["pos"]
        return a["idx"] < b["idx"])

    var ordered: Array[String] = []
    for entry in ranked:
        ordered.append(entry["name"])
    return ordered


# Reading position of one keyword: its index in the description, else in the bonus line (pushed
# past the description so bonus keywords sort after body ones), else a large sentinel so it
# trails everything readable.
const KEYWORD_POSITION_UNREAD := 1 << 30

static func _keyword_position(keyword: String, description: String, bonus_text: String) -> int:
    if keyword == "Power":
        var power_pos := _power_mention_position(description)
        if power_pos >= 0:
            return power_pos
        power_pos = _power_mention_position(bonus_text)
        return description.length() + 1 + power_pos if power_pos >= 0 else KEYWORD_POSITION_UNREAD
    var regex := RegEx.new()
    regex.compile("(?i)\\b" + _escape_for_regex(keyword) + "\\b")
    var m := regex.search(description)
    if m:
        return m.get_start()
    m = regex.search(bonus_text)
    if m:
        return description.length() + 1 + m.get_start()
    return KEYWORD_POSITION_UNREAD


# Tags are authored strings, so a stray regex metacharacter must not become a pattern.
static func _escape_for_regex(text: String) -> String:
    var escaped := ""
    for c in text:
        if c in "\\^$.|?*+()[]{}":
            escaped += "\\"
        escaped += c
    return escaped


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
