class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)
signal mouse_entered_card
signal mouse_exited_card

# At the top of your CardUI class, add these constants:
const TOOLTIP_OFFSET_X = 2  # Horizontal distance from card
const TOOLTIP_HEIGHT = 108    # Approximate height of each tooltip
const TOOLTIP_SPACING = 1     # Space between tooltips
# Keyword tooltips wait this long on a hovered card. Was 1.0s, which made the most information-dense
# object in the game the slowest to explain itself; STS2 shows them at once. 0.25s still lets a
# sweep across the fan pass without popping any (Julien, 2026-09-26, H-190 idea 9).
const CARD_TOOLTIP_DELAY := 0.25

enum PlayableGlow { NONE, AVAILABLE, HOT, NEUTRAL }

const GLOW_DEFAULT_COLOR := Color(0.184314, 0.917647, 0.843137)
const GLOW_BORDER_WIDTH_HOT := 5
const GLOW_BORDER_WIDTH_AVAILABLE := 3
const GLOW_SHADOW_ALPHA_HOT := 0.65
const GLOW_SHADOW_ALPHA_AVAILABLE := 0.35
const GLOW_SHADOW_SIZE_HOT := 7
const GLOW_SHADOW_SIZE_AVAILABLE := 4
const GLOW_HOT_MAX_ALPHA := 1.0
const GLOW_HOT_MIN_ALPHA := 0.35
const GLOW_AVAILABLE_ALPHA := 0.5
const GLOW_PULSE_DURATION := 1.1
# Dim unplayable cards by darkening (RGB multiply at full alpha) rather than
# reducing alpha. Alpha-dimming bleeds the background through and dims
# unevenly because the card is built from several stacked opaque layers;
# a full-alpha brightness multiply is uniform regardless of layer stacking.
# Two dim levels depending on WHY the card can't be played right now: a lighter dim when
# there's simply no power banked yet (roll_value <= 0, "haven't rolled"), and a darker dim
# when power IS banked but this specific card's requirement isn't met by it - the darker
# level reads as more "definitely no" than the lighter "not yet" state.
const UNPLAYABLE_MODULATE_NO_POWER := Color(0.75, 0.75, 0.75, 1.0)
const UNPLAYABLE_MODULATE_HAS_POWER := Color(0.6, 0.6, 0.6, 1.0)

# Warm overbright flash on the requirement ribbon when a pick-up is refused for failing it.
const RIBBON_FLASH_COLOR := Color(1.9, 1.25, 1.25, 1.0)
# Pick-up refusal message. Same recipe as the act/turn banners (MinionPro-Bold, brown
# outline, drop shadow) so it reads as part of the game's transient-message language, but
# in a warm red instead of their gold - this is a refusal, not an announcement.
const ERROR_SFX := preload("res://sounds/error.wav")
const REFUSAL_FONT := preload("res://fonts/MinionPro-Bold.otf")
const REFUSAL_MSG_NO_POWER := "You need %s%sPower to play this card"
const REFUSAL_MSG_REQUIREMENT := "Card requirements are not met"
const REFUSAL_MSG_COLOR := Color(0.98, 0.44, 0.38, 1.0)
const REFUSAL_MSG_WIDTH := 560.0
const REFUSAL_MSG_HOLD := 1.0
const REFUSAL_MSG_FONT_SIZE := 24

# The played card's whole send-off (press, stage, hold, then the discard, the burn or the hero)
# lives in card_send_off.gd since 2026-09-24, shared with the Red socket's display. Its tuning
# levers (STAGE_CENTER, HOLD_*, EXIT_*, ABSORB_*, BURN_*) are there.
const CardSendOff := preload("res://scenes/card_ui/card_send_off.gd")
# Same resource as CardSendOff.BURN_SHADER (preload caches it), kept here for the harnesses.
const BURN_SHADER := preload("res://scenes/card_ui/card_burn.gdshader")

# Aiming (2026-09-24, after STS2's NCardPlay.CenterCard): the card being aimed shrinks to 0.75
# and leans toward the cursor, so the arrow and the target own the moment instead of a full-size
# card parked over the hand. On the ART only: the root stays where the aim state put it, because
# the arrow's hit probe, the drop detector and the tutorial all read the root.
const AIM_SCALE := 0.75
const AIM_POSE_TIME := 0.16
const AIM_LEAN_GAIN := 0.16
const AIM_LEAN_MAX := 0.13       # radians, ~7.5 degrees
const AIM_LEAN_RESPONSE := 12.0  # 1/s, how fast the lean chases the cursor

# Shared across every CardUI/CardMenuUI instance via the .tscn (sub-resources aren't
# resource_local_to_scene by default) - never mutate this one directly, duplicate() it first
# (see set_upgraded_title_color below), same pattern as MUSCLE_STATUS.duplicate() in bolster.gd.
const TITLE_LABEL_SETTINGS := preload("res://scenes/card_ui/card_title.tres")
const UPGRADED_TITLE_COLOR := Color(0.36, 0.85, 0.36)

# Width available to the Title label between its symmetric banner insets (see the Title node's
# offset_left/offset_right in the .tscn) - the insets reserve the rarity gem's slot on the
# right and mirror it on the left so the title stays optically centered on the card. Card is
# 140 wide, 18px inset each side.
const TITLE_MAX_WIDTH := 104.0
# Descending candidates - the first size whose MEASURED width fits is used. Char-count
# thresholds (the previous approach) can't work here: caps width varies too much per glyph
# ("Necromancy+" is 11 chars but wider than several 13-char names). 15 is the design size;
# 9 only exists for extreme names ("Perpetual Motion+") that Julien may rename instead.
const TITLE_FONT_SIZE_CANDIDATES: Array[int] = [15, 12, 10, 9]

# Long descriptions (dynamic-resolved text can run even longer than the static string) overflow
# the fixed-height DescriptionPanel at the default 12pt. Descending candidates - the first size
# whose MEASURED wrapped height fits the panel wins. Character counts (the previous approach)
# failed here for the same reason they failed for titles: they ignore per-glyph width, and they
# ignore the inline Power glyph the colorizer injects, which costs ~a word of width but ZERO
# characters. Crescendo (59 chars, one under the old 60-char threshold) stayed at 12pt and spilled
# a 4th line out of the panel because of exactly that. 9 and 8 are unreached safety nets since the
# panel grew (see DESC_PANEL_HEIGHT); the worst card in the pool, All In+, now lands at 10.
# Starts at 14 since 2026-09-26 (H-190 idea 6, Julien's pick): most cards hold one or two short lines
# in a 64px band, and at 12 they read small on hover and on rewards. Measured windowed over all 168
# cards: 128 keep 14, 32 step to 13, 8 go lower. Resolving the number on a roll changes the size of
# only 6 cards (Tsunami, All In, Avalanche and their + versions; 4 of them already did at 12).
const DESC_FONT_SIZE_CANDIDATES: Array[int] = [14, 13, 12, 11, 10, 9, 8]

# DescriptionPanel is an INVISIBLE layout box: its stylebox bg_color is byte-identical to the card
# body's on the Celestial and Blessing variants, and differs by ~0.001 on the normal one (compare
# card_ui_description_panel_*.tres against card_ui_*.tres). So its height can grow into the 22px of
# dead space below it - y188..210, which only the BonusEffect row ever occupies - with zero visual
# change, buying long descriptions 1-2 font steps instead of making them pay for the side margins.
# The box spans the WHOLE band, 144..208, so DescriptionCenter's vertical centring is honest. At the
# old 56 the box stopped at 200 while the card's visible inner edge is at 208, so the centred block
# sat 8px high in the card - measured as an identical +8 skew on Strike, Crescendo, Ooga Booga,
# Transmutation, All In+ and Resonance alike. Cards WITH a bonus effect keep 44 (BonusSeparator sits
# at y188). Must be applied BEFORE _apply_description(), which measures against this height.
const DESC_PANEL_TOP := 144.0
const DESC_PANEL_HEIGHT := 64.0
const DESC_PANEL_HEIGHT_WITH_BONUS := 44.0

# The font step-down deliberately measures against LESS than the box it centres in. Fitting to the
# full 64 promotes the two longest cards (All In+, Resonance) from 11pt/4 lines to 12pt/5 lines,
# which lands their block 0.5-1px off the gold border - the same edge-crowding the 6px side margins
# removed, on the other axis. Capping the fit at 56 holds every card's worst gap at 7px while the
# taller box still does the centring. Applied with minf(), so the 44 bonus case still fits to 44.
const DESC_FIT_BUDGET := 56.0


static func title_font_size_for(text: String) -> int:
    var font: Font = TITLE_LABEL_SETTINGS.font
    for size: int in TITLE_FONT_SIZE_CANDIDATES:
        if font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x <= TITLE_MAX_WIDTH:
            return size
    return TITLE_FONT_SIZE_CANDIDATES[-1]


var current_glow_state: PlayableGlow = PlayableGlow.NONE

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
const SUPPORT_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal_celestial.tres")

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal.tres")
const BASE_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial.tres")
const DRAG_STYLEBOX := preload("res://scenes/card_ui/card_drag_stylebox.tres")
const DRAG_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_drag_celestial_stylebox.tres")

const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_test.tres")
const HOVER_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_test.tres")

const NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none.tres")
const MIN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_min.tres")
const MAX_STYLEBOX := preload("res://scenes/card_ui/card_requirement_max.tres")
const EVEN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_even.tres")
const ODD_STYLEBOX := preload("res://scenes/card_ui/card_requirement_odd.tres")
const RED_STYLEBOX := preload("res://scenes/card_ui/card_requirement_red.tres")
const EXACT_STYLEBOX := preload("res://scenes/card_ui/card_requirement_exact.tres")
const MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_multiple.tres")

const REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_requirement_ribbon.tres")
const NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon.tres")

const BONUS_MIN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_min.tres")
const BONUS_MAX_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_max.tres")
const BONUS_EVEN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_even.tres")
const BONUS_ODD_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_odd.tres")
const BONUS_RED_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_red.tres")
const BONUS_EXACT_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_exact.tres")
const BONUS_MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_multiple.tres")


const CELESTIAL_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_celestial.tres")
const CELESTIAL_ART_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial_art.tres")
const CELESTIAL_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_celestial.tres")
const CELESTIAL_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_celestial.tres")
const BLESSING_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_blessing.tres")
# Description is now a RichTextLabel (converted so keyword colors from Card.get_colorized_
# description() can render), which has no `label_settings` property. This LabelSettings
# resource is kept preloaded anyway, purely as the source of truth for .outline_color below -
# it's the only property that actually differs between the normal and Celestial description
# styles; font/size/color/shadow are identical between the two, and now live as static theme
# overrides directly on the Description node in card_ui.tscn instead.
const CELESTIAL_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/celestial_card_description_label.tres")

const BLESSING_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_blessing.tres")
const BLESSING_STYLEBOX := preload("res://scenes/card_ui/card_ui_blessing.tres")
const BLESSING_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_blessing.tres")
const BLESSING_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/blessing_card_description_label.tres")

# --- Hex: cards an enemy forced into your deck -----------------------------------------
# Cold ash body with a DULL IRON border. Normal, Blessing and Celestial cards all share the
# same gold border, so dropping gold is the loudest mark available for "this one is not
# yours", and it is one of the few that survives the hand fan (cards overlap at separation
# -35, so only the left ~105px and the banner are ever read).
# Measured and rejected: treating the ART. Desaturating it reads as the game already-spent
# "you cannot play this" dim (UNPLAYABLE_MODULATE_*), and on hex.png it collapses to a black
# rectangle outright, because that art carries its read in chroma rather than luminance. The
# art is therefore left completely untouched and the chrome carries the whole identity.
const HEX_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_hex.tres")
const HEX_STYLEBOX := preload("res://scenes/card_ui/card_ui_hex.tres")
const HEX_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_hex.tres")
const HEX_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/hex_card_description_label.tres")
const HEX_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_hex.tres")
const HEX_NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon_hex.tres")
const HEX_TITLE_COLOR := Color(0.729412, 0.74902, 0.705882)
const HEX_TITLE_OUTLINE_COLOR := Color(0.086275, 0.090196, 0.086275)

# Rarity gem in the banner's right slot (the old dead SupportIcon spot). Every tier shows a
# gem - Common included (muted stone gray), per Julien: an empty slot on most cards read as
# "something's missing" rather than "this card is common". Starter cards get the Common gem
# for free since COMMON is the enum default on Card.rarity_tier.
const RARITY_GEM_TEXTURES := {
    Card.RarityTier.COMMON: preload("res://assets/images/rarity_gem_common.png"),
    Card.RarityTier.UNCOMMON: preload("res://assets/images/rarity_gem_uncommon.png"),
    Card.RarityTier.RARE: preload("res://assets/images/rarity_gem_rare.png"),
}

@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats
@export var player_modifiers: ModifierHandler 

#@onready var panel: Panel = $Panel
#@onready var description: Label = $Description
#@onready var icon: TextureRect = $Icon


@onready var card_background: Panel = $CardBackground
@onready var panel: Panel = $CardBackground/CardFrame
@onready var card_banner: Panel = $CardBackground/CardFrame/CardBanner
@onready var title: Label = $CardBackground/CardFrame/CardBanner/Title

@onready var icon: TextureRect = $CardBackground/CardFrame/Panel/CardArt
@onready var description_panel: Panel = $CardBackground/CardFrame/DescriptionPanel

@onready var description: RichTextLabel = $CardBackground/CardFrame/DescriptionPanel/DescriptionCenter/Description

var _glow_tween: Tween
var _base_frame_stylebox: StyleBox
var _hot_frame_stylebox: StyleBoxFlat

@onready var requirement_panel: Panel = $CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: Label = $CardBackground/CardFrame/RequirementPanel/RequirementLabel

@onready var bonus_effect: HBoxContainer = $CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: Label = $CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_texture: TextureRect = $CardBackground/CardFrame/BonusEffect/BonusEffectTexture
@onready var bonus_effect_label: RichTextLabel = $CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var card_frame: Panel = $CardBackground/CardFrame
@onready var bonus_separator: ColorRect = $CardBackground/CardFrame/BonusSeparator


@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine
@onready var targets: Array[Node] = []

@onready var rarity_gem: TextureRect = $CardBackground/CardFrame/CardBanner/RarityGem

# Pick-up refusal feedback. Deliberately NOT stored in `tween`: card_base_state.enter() kills
# that one, and the refusal plays exactly while we transition back to BASE.
var _refusal_tween: Tween
var _ribbon_tween: Tween
# One refusal message on screen at a time across the whole hand, hence static: refusing a
# second card replaces the first rather than stacking two labels on top of each other.
static var _refusal_message_node: RichTextLabel


# Whether reaching for this card should be refused instead of starting a drag.
func is_drag_blocked() -> bool:
    return card != null and card.would_no_op_now()


# "You can't pick that up (yet)" - a short shake plus, when there's a specific reason to
# point at, a pulse on the requirement ribbon. No new text is invented: the ribbon already
# reads "MIN 6" on the card face, so drawing the eye to it beats printing the same fact
# somewhere else on screen.
func play_pickup_refusal() -> void:
    SFXPlayer.play(ERROR_SFX, false, 1.0, -3.0)
    _show_refusal_message(_refusal_text())

    # Shake CardBackground, never the CardUI root: the fan owns the root's position and
    # rotation and re-stomps both on every fan_hand_requested - which transitioning back to
    # BASE emits - so a shake there would be wiped mid-animation. CardBackground's parent is
    # a plain Control (not a container), so nothing re-lays it out behind our back.
    # Through shake_x rather than CardBackground.position directly: the visual follower below
    # also writes that position, and the two are composed in _apply_visual_transform().
    if _refusal_tween and _refusal_tween.is_valid():
        _refusal_tween.kill()
    shake_x = 0.0
    _refusal_tween = create_tween()
    for offset: float in [9.0, -7.0, 5.0, -3.0, 0.0]:
        _refusal_tween.tween_property(self, "shake_x", offset, 0.045) \
            .set_trans(Tween.TRANS_SINE)

    # Only flash the ribbon when the requirement is the actual reason. Blocks that happen
    # before the first roll have no ribbon to blame, and a card with no requirement has no
    # ribbon at all - flashing either would point at the wrong thing.
    if requirement_panel == null or not requirement_panel.visible or card.meets_requirement():
        return
    if _ribbon_tween and _ribbon_tween.is_valid():
        _ribbon_tween.kill()
    requirement_panel.pivot_offset = requirement_panel.size / 2.0
    _ribbon_tween = create_tween()
    _ribbon_tween.tween_property(requirement_panel, "scale", Vector2(1.18, 1.18), 0.08) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _ribbon_tween.parallel().tween_property(requirement_panel, "modulate", RIBBON_FLASH_COLOR, 0.08)
    _ribbon_tween.tween_property(requirement_panel, "scale", Vector2.ONE, 0.22) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    # Restore to the authored WHITE explicitly rather than to a captured live value - a second
    # refusal landing mid-flash would otherwise bake the brightened tint in permanently.
    _ribbon_tween.parallel().tween_property(requirement_panel, "modulate", Color.WHITE, 0.22)


# Which line to show, and the Power glyph welded into it. The glyph comes from
# KeywordColorizer so the message uses the same asset, the same [img] form and the same
# font_size + 2 sizing convention as every card that prints it - and picks up any future
# change to the glyph for free. NBSP between icon and word for the same reason card text
# uses one: the two must never be split across a line break.
func _refusal_text() -> String:
    if Global.roll_value > 0:
        return REFUSAL_MSG_REQUIREMENT
    return REFUSAL_MSG_NO_POWER % [
        KeywordColorizer.power_glyph_img(REFUSAL_MSG_FONT_SIZE + 2),
        KeywordColorizer.NBSP,
    ]


# Short "here's why" line that floats above the refused card and fades out.
func _show_refusal_message(text: String) -> void:
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer == null:
        return
    # Kill-before-spawn: without this, refusing several cards in a row leaves a stack of
    # labels fading independently (the same leak shape the tooltips had).
    if is_instance_valid(_refusal_message_node):
        _refusal_message_node.queue_free()

    # RichTextLabel rather than Label: only BBCode can render the inline [img] glyph.
    # That costs the Label conveniences - no label_settings (styling goes through theme
    # overrides) and no horizontal_alignment (centring is a [center] tag) - and it defaults
    # to mouse_filter STOP where Label is IGNORE, which would silently eat clicks aimed at
    # the cards underneath.
    var label := RichTextLabel.new()
    label.bbcode_enabled = true
    label.fit_content = true
    label.scroll_active = false
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.custom_minimum_size = Vector2(REFUSAL_MSG_WIDTH, 0.0)
    label.size = Vector2(REFUSAL_MSG_WIDTH, 40.0)
    label.z_index = 200
    label.add_theme_font_override("normal_font", REFUSAL_FONT)
    label.add_theme_font_size_override("normal_font_size", REFUSAL_MSG_FONT_SIZE)
    label.add_theme_color_override("default_color", REFUSAL_MSG_COLOR)
    label.add_theme_color_override("font_outline_color", Color(0.196078, 0.0823529, 0.0, 1.0))
    label.add_theme_constant_override("outline_size", 6)
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
    label.add_theme_constant_override("shadow_offset_x", 3)
    label.add_theme_constant_override("shadow_offset_y", 3)
    label.text = "[center]%s[/center]" % text

    ui_layer.add_child(label)
    _refusal_message_node = label

    # Centred over the refused card and lifted clear of the fan, then clamped so a card at
    # either end of the hand can't push the text off screen.
    var viewport_width := get_viewport_rect().size.x
    var centred_x: float = global_position.x + size.x * 0.5 - REFUSAL_MSG_WIDTH * 0.5
    label.position = Vector2(
        clampf(centred_x, 8.0, maxf(viewport_width - REFUSAL_MSG_WIDTH - 8.0, 8.0)),
        global_position.y - 54.0)

    # Tween owned by the label, so it dies with it rather than writing to a freed node.
    label.modulate.a = 0.0
    var drift_to := label.position.y - 12.0
    var msg_tween := label.create_tween()
    msg_tween.tween_property(label, "modulate:a", 1.0, 0.08)
    msg_tween.parallel().tween_property(label, "position:y", drift_to, 0.2) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    msg_tween.tween_interval(REFUSAL_MSG_HOLD)
    msg_tween.tween_property(label, "modulate:a", 0.0, 0.25)
    msg_tween.tween_callback(label.queue_free)


var original_index := 0
var parent: Control
var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var card_instance_id: int = 0



func _ready() -> void:
    #_setup_card_style()
    Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
    Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
    Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
    Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
    card_state_machine.init(self)
    Events.red_dice_rolled.connect(_on_red_dice_rolled)
    Events.red_dice_rolled.connect(_on_dice_rolled_update_description)
    Events.dice_rolled.connect(_on_dice_rolled_update_description)
    Events.dice_roll_reset.connect(_on_dice_rolled_update_description)
    Events.change_current_power.connect(_on_dice_rolled_update_description)
    if card:
        card_instance_id = card.instance_id
    



func _input(event: InputEvent) -> void:
    card_state_machine.on_input(event)


# ===========================================================================
# VISUAL FOLLOWER (2026-09-23)
#
# The Hand is an HBoxContainer: it teleports every CardUI root to its slot on each sort, and the
# fan stomps rotation/y right after - so nothing in the hand could move smoothly. A played card's
# neighbours snapped shut, a drawn card faded in where it landed, and hover snapped its scale and
# rotation in one frame. Every pixel of the card lives under CardBackground (Aura is unused and
# hidden), so the root is left to teleport and CardBackground carries a transform that keeps the
# art where it was on screen, then glides it home. Anything that reads the ROOT (the hover hit
# area, the drop detector, targeting, the tutorial) is unaffected.
# ===========================================================================
const FOLLOW_TIME := 0.22
const DRAW_FLIGHT_TIME := 0.36
# The deal plays five times in a row every turn, so the hop out of the pile stays small (Julien,
# 2026-09-25 playtest: "a bit too much since it happens so often"). Was 70px, 0.3, -0.5 rad.
const DRAW_ARC := 35.0             # px the drawn card rises mid-flight on its way out of the pile
const DRAW_START_SCALE := 0.5
const DRAW_START_ROTATION := -0.25 # radians, it leaves the pile tilted and rights itself
const PICKUP_TIME := 0.1
# Drag tilt (Balatro-style weight): the card leans with its horizontal speed and swings back.
const DRAG_TILT_PER_SPEED := 0.00014  # radians per px/s
# The roll wakes the cards (H-190 idea 3). The hop is quick up, softer down; the dip is half as deep
# and slower, a card settling rather than jumping.
const WAKE_HOP := 8.0
const WAKE_UP_TIME := 0.12
const WAKE_DOWN_TIME := 0.22
const DIP_DEPTH := 4.0
const DIP_TIME := 0.3
const DRAG_TILT_MAX := 0.2
const DRAG_SPEED_SMOOTHING := 20.0    # 1/s, low-pass on the raw per-frame speed
const DRAG_TILT_RESPONSE := 14.0      # 1/s, how fast the tilt chases its target

var shake_x := 0.0 : set = _set_shake_x
# Vertical nudge of the art only (H-190 idea 3, the roll wakes the cards): a hop when a roll makes
# this card playable, a dip when a roll takes it away. Same channel style as shake_x, so the root,
# the hit area and the tutorial never move.
var hop_y := 0.0 : set = _set_hop_y
var _hop_tween: Tween
var drag_tilt_active := false
var _lag_offset := Vector2.ZERO
var _lag_rotation := 0.0
var _lag_scale := 1.0
var _tilt := 0.0
var _drag_speed := 0.0
var _prev_drag_x := 0.0
var _follow_tween: Tween
var _follow_from_offset := Vector2.ZERO
var _follow_from_rotation := 0.0
var _follow_from_scale := 1.0
var _follow_arc := 0.0
var _anchored_root_xform := Transform2D()
var _anchor_valid := false
var _visual_record := Transform2D()
var _has_visual_record := false
# Global centre of the draw pile this card is being dealt from, consumed by the first
# follow_to_slot() AFTER the container has placed the card. INF = not being dealt.
var _pending_draw_from := Vector2.INF
# Set by Hand once its container has sorted this card into a slot. Adding the first card also
# resizes the hand, and that resize runs the fan BEFORE the sort - anchoring the flight then
# would measure it from the card's pre-layout spot, and the sort would drag it across the screen.
var _placed_by_container := false
# Aim pose (see AIM_*), composed into the art on top of the follower lag.
var _aim_scale := 1.0
var _aim_lean := 0.0
var _aim_tracking := false
var _aim_tween: Tween
# Set when the send-off takes the art over: from then on nothing on this card writes it.
var _flight_owned := false
# Set when the card is played. Its description stops following the dice from that moment.
var _played := false


func _set_shake_x(value: float) -> void:
    shake_x = value
    _apply_visual_transform()


func _set_hop_y(value: float) -> void:
    hop_y = value
    _apply_visual_transform()


func _process(delta: float) -> void:
    _update_drag_tilt(delta)
    _update_aim_lean(delta)
    # What was on screen last frame. _process runs before tweens and before the deferred flush in
    # which the Hand re-sorts, so this is the pose to hold when the root is teleported this frame.
    if card_background != null:
        _visual_record = card_background.get_global_transform()
        _has_visual_record = true


func _apply_visual_transform() -> void:
    if card_background == null or _flight_owned:
        return
    card_background.pivot_offset = card_background.size / 2.0
    card_background.position = _lag_offset + Vector2(shake_x, hop_y)
    card_background.rotation = _lag_rotation + _tilt + _aim_lean
    var s := _lag_scale * _aim_scale
    card_background.scale = Vector2(s, s)


# The Hand calls this after placing the root (container sort + fan). Holds the art where it was
# and glides it into the new slot; a no-op when the root did not actually move.
func follow_to_slot(duration: float = FOLLOW_TIME) -> void:
    if not is_node_ready() or card_background == null:
        return
    var root_xf := get_global_transform()
    if _pending_draw_from != Vector2.INF:
        if not _placed_by_container:
            return
        var from := _pending_draw_from
        _pending_draw_from = Vector2.INF
        _anchored_root_xform = root_xf
        _anchor_valid = true
        _anchor_visual(_xform_centered_at(from, DRAW_START_ROTATION, DRAW_START_SCALE),
                DRAW_FLIGHT_TIME, DRAW_ARC)
        return
    if _anchor_valid and root_xf.is_equal_approx(_anchored_root_xform):
        return
    var had_history := _anchor_valid and _has_visual_record
    _anchored_root_xform = root_xf
    _anchor_valid = true
    if had_history:
        _anchor_visual(_visual_record, duration, 0.0)


# For callers that teleport the root themselves (hover, drag pick-up): pass the art's global
# transform from BEFORE the move, and it glides from there.
func hold_visual(previous_global: Transform2D, duration: float) -> void:
    if card_background == null:
        return
    _anchored_root_xform = get_global_transform()
    _anchor_valid = true
    _anchor_visual(previous_global, duration, 0.0)


# Deal this card out of the draw pile instead of fading it in where it lands.
# Still leaving the draw pile: the deal owns the art until it lands, so a wake must not run on top.
func is_in_draw_flight() -> bool:
    if _pending_draw_from != Vector2.INF:
        return true
    return _follow_tween != null and _follow_tween.is_running() and _follow_arc > 0.0


# A roll just made this card playable. Called by Hand with the card's place in the stagger.
func play_wake(delay: float) -> void:
    _run_hop(delay, -WAKE_HOP, WAKE_UP_TIME, WAKE_DOWN_TIME)


# A roll just took this card away (a Max or an Exact overshot, a Mult missed).
func play_dip(delay: float) -> void:
    _run_hop(delay, DIP_DEPTH, DIP_TIME * 0.4, DIP_TIME * 0.6)


# A new beat takes over from wherever the last one is, so two rolls in a row never snap.
func _run_hop(delay: float, peak: float, out_time: float, back_time: float) -> void:
    if _hop_tween and _hop_tween.is_valid():
        _hop_tween.kill()
    _hop_tween = create_tween()
    if delay > 0.0:
        _hop_tween.tween_interval(delay)
    _hop_tween.tween_property(self, "hop_y", peak, out_time) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hop_tween.tween_property(self, "hop_y", 0.0, back_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func begin_draw_flight(pile_center: Vector2) -> void:
    _pending_draw_from = pile_center


func mark_placed_by_container() -> void:
    _placed_by_container = true


func _xform_centered_at(center: Vector2, rot: float, s: float) -> Transform2D:
    var xf := Transform2D(rot, Vector2(s, s), 0.0, Vector2.ZERO)
    xf.origin = center - xf.basis_xform(card_background.size / 2.0)
    return xf


func _anchor_visual(global_xf: Transform2D, duration: float, arc: float) -> void:
    card_background.pivot_offset = card_background.size / 2.0
    var local := get_global_transform().affine_inverse() * global_xf
    var rot := local.get_rotation()
    var sc := local.get_scale()
    var s := (absf(sc.x) + absf(sc.y)) * 0.5
    # Control local transform = translate(position + pivot) * rotate * scale * translate(-pivot),
    # so the position that reproduces this origin is origin - pivot + R*S*pivot.
    var c := card_background.pivot_offset
    var p := local.origin - c + Transform2D(rot, Vector2(s, s), 0.0, Vector2.ZERO).basis_xform(c)
    if _follow_tween and _follow_tween.is_valid():
        _follow_tween.kill()
    _lag_offset = p - Vector2(shake_x, hop_y)
    _lag_rotation = rot - _tilt - _aim_lean
    _lag_scale = s / maxf(_aim_scale, 0.001)
    if _lag_offset.length() < 0.5 and absf(_lag_rotation) < 0.002 and absf(_lag_scale - 1.0) < 0.002:
        _lag_offset = Vector2.ZERO
        _lag_rotation = 0.0
        _lag_scale = 1.0
        _apply_visual_transform()
        return
    _follow_from_offset = _lag_offset
    _follow_from_rotation = _lag_rotation
    _follow_from_scale = _lag_scale
    _follow_arc = arc
    _apply_visual_transform()
    _follow_tween = create_tween()
    _follow_tween.tween_method(_follow_step, 0.0, 1.0, duration) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _follow_step(t: float) -> void:
    var k := 1.0 - t
    _lag_offset = _follow_from_offset * k + Vector2(0.0, -_follow_arc * sin(PI * t))
    _lag_rotation = _follow_from_rotation * k
    _lag_scale = lerpf(_follow_from_scale, 1.0, t)
    _apply_visual_transform()


func _update_drag_tilt(delta: float) -> void:
    if delta <= 0.0:
        return
    var speed := 0.0
    if drag_tilt_active:
        speed = (global_position.x - _prev_drag_x) / delta
    _prev_drag_x = global_position.x
    _drag_speed = lerpf(_drag_speed, speed, 1.0 - exp(-DRAG_SPEED_SMOOTHING * delta))
    var target: float = clampf(_drag_speed * DRAG_TILT_PER_SPEED, -DRAG_TILT_MAX, DRAG_TILT_MAX) \
            if drag_tilt_active else 0.0
    if absf(_tilt) < 0.0005 and absf(target) < 0.0005:
        if _tilt != 0.0:
            _tilt = 0.0
            _apply_visual_transform()
        return
    _tilt = lerpf(_tilt, target, 1.0 - exp(-DRAG_TILT_RESPONSE * delta))
    _apply_visual_transform()


func start_drag_tilt() -> void:
    drag_tilt_active = true
    _prev_drag_x = global_position.x
    _drag_speed = 0.0


func stop_drag_tilt() -> void:
    drag_tilt_active = false


# --- Aim pose ---------------------------------------------------------------------------------
# The socketed Red card is aimed while hidden (dice.gd shows the socket instead), so it gets no
# pose - nothing would show it, and it must not carry one into its flight.
func begin_aim_pose() -> void:
    if _flight_owned or not visible or Global.playing_red_card:
        return
    _aim_tracking = true
    if _aim_tween and _aim_tween.is_valid():
        _aim_tween.kill()
    _aim_tween = create_tween()
    _aim_tween.tween_method(_set_aim_scale, _aim_scale, AIM_SCALE, AIM_POSE_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# Leaving AIMING keeps the pose where it is: a play hands it to the send-off, a cancel folds it
# back through end_aim_pose() when the card returns to BASE.
func stop_aim_tracking() -> void:
    _aim_tracking = false


# Back to the hand: the art is held exactly where it is on screen and glides home, like any other
# move of the root (hold_visual), instead of popping back to full size.
func end_aim_pose() -> void:
    if _aim_tween and _aim_tween.is_valid():
        _aim_tween.kill()
    _aim_tracking = false
    if is_equal_approx(_aim_scale, 1.0) and is_zero_approx(_aim_lean):
        return
    if card_background == null or _flight_owned:
        _aim_scale = 1.0
        _aim_lean = 0.0
        return
    var art_before := card_background.get_global_transform()
    _aim_scale = 1.0
    _aim_lean = 0.0
    hold_visual(art_before, PICKUP_TIME)


func _set_aim_scale(v: float) -> void:
    _aim_scale = v
    _apply_visual_transform()


func _update_aim_lean(delta: float) -> void:
    if not _aim_tracking or card_background == null or delta <= 0.0:
        return
    var center := card_background.get_global_transform() * (card_background.size * 0.5)
    var to_mouse := get_global_mouse_position() - center
    var target := 0.0
    if to_mouse.length() > 1.0:
        # 0 when the cursor is straight above the card, positive (clockwise) when it is to the right.
        target = clampf(atan2(to_mouse.x, -to_mouse.y) * AIM_LEAN_GAIN, -AIM_LEAN_MAX, AIM_LEAN_MAX)
    _aim_lean = lerpf(_aim_lean, target, 1.0 - exp(-AIM_LEAN_RESPONSE * delta))
    _apply_visual_transform()


# Where the aim arrow starts: the middle of the art's top edge, so it follows the smaller, leaning
# card instead of the root's untouched top edge.
func aim_arrow_origin() -> Vector2:
    if card_background == null:
        return global_position + Vector2(size.x / 2.0, 0.0)
    return card_background.get_global_transform() * Vector2(card_background.size.x / 2.0, 0.0)


func animate_to_position(new_position: Vector2, duration: float) -> void:
    tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "global_position", new_position, duration)


func play() -> void:
    if not card:
        return
    # Freeze the text BEFORE the play. The play resets Power, and this card listens to
    # dice_roll_reset like every card in hand, so "Deal X3 damage (9)" used to drop back to
    # "Deal X3 damage" while it was still on the stage (2026-09-24).
    _played = true
    # Record where the card was played from, so effects like refuel can launch their "dice
    # fly back to the die" visual from the card itself. Set before card.play() because that's
    # what fires the effect (and the refuel signal) synchronously.
    Global.last_played_card_position = global_position + size / 2.0
    _prune_stale_targets()
    card.play(targets, char_stats, player_modifiers)
    _fly_to_discard_and_free(Card.last_play_report())


# The played card's visual send-off - the effect already fired above, this only moves the card.
# `report` is Card.last_play_report(): which pile the rules put it in, whether it missed (a
# fizzle), and when its last delayed hit lands. Called without one (harnesses), it reads the card
# as it stands.
func _fly_to_discard_and_free(report: Dictionary = {}) -> void:
    _played = true
    set_process_input(false)  # stop routing input into the now-discarding state machine
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    disabled = true
    z_index = 100
    if tween and tween.is_valid():
        tween.kill()  # stop any in-progress positioning tween (e.g. the aim move-up) from fighting the fly
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    # A card played straight from the red-dice socket never went through the drag state on its
    # final play, so unlike every other play path it can still be a CHILD OF THE HAND here. It must
    # leave the hand NOW: card.play() already added its Card to the discard pile via
    # Events.card_played, so if End Turn fires during this flight, player_handler.discard_cards()
    # would iterate it as a hand card and add the SAME Card object to the pile a second time - two
    # copies drawn after the next reshuffle.
    if ui_layer != null and get_parent() != ui_layer:
        reparent(ui_layer)
    # Hidden = it sat in the Red socket (dice.gd hides the real card there). The socket's display
    # is what the player was looking at, and dice.gd flies THAT, pile arrival included, so this
    # card only had to leave the hand.
    if not visible:
        queue_free()
        return
    var exhausted: bool = report.get("exhausted", card.should_exhaust())
    var dice_type: String = report.get("dice_type", Global.dice_type)
    _hand_art_to_flight()
    var send_off = CardSendOff.new()
    send_off.ui_layer = ui_layer
    send_off.art = card_background
    send_off.fizzled = report.get("fizzled", false)
    send_off.hold_extra = report.get("hold_extra", 0.0)
    send_off.accent = DicePalette.accent(dice_type)
    send_off.route = CardSendOff.route_for(card, exhausted)
    send_off.pile_button = CardSendOff.pile_for(ui_layer, send_off.route)
    add_child(send_off)
    send_off.start()


# The send-off takes the art over from here. Whatever pose it is in (follower lag, aim pose, drag
# tilt, a refusal shake) stays exactly as it is on screen and eases out over the glide, and
# nothing on this card writes the art again.
func _hand_art_to_flight() -> void:
    if _follow_tween and _follow_tween.is_valid():
        _follow_tween.kill()
    if _aim_tween and _aim_tween.is_valid():
        _aim_tween.kill()
    if _refusal_tween and _refusal_tween.is_valid():
        _refusal_tween.kill()
    _aim_tracking = false
    drag_tilt_active = false
    _flight_owned = true
    # Hover tooltips on a card that is already flying away read as the hand still being live.
    _cleanup_card_tooltips()


func _reset_visual_lag() -> void:
    if _follow_tween and _follow_tween.is_valid():
        _follow_tween.kill()
    if _aim_tween and _aim_tween.is_valid():
        _aim_tween.kill()
    _lag_offset = Vector2.ZERO
    _lag_rotation = 0.0
    _lag_scale = 1.0
    _tilt = 0.0
    _aim_scale = 1.0
    _aim_lean = 0.0
    _aim_tracking = false
    drag_tilt_active = false
    shake_x = 0.0


# End-of-turn/random-discard send-off: a much quicker, plainer cousin of the played-card
# flight above - no staging pause, no resolve flash, no trail (nothing "resolved"; the hand
# is just being swept away, and up to 5 of these overlap on End Turn, so each one stays
# cheap). Called by hand.gd::discard_card in place of the old instant queue_free.
func fly_hand_discard() -> void:
    set_process_input(false)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    disabled = true
    z_index = 100
    if tween and tween.is_valid():
        tween.kill()
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if not ui_layer:
        # No layer to fly on (shouldn't happen in battle) - keep the old instant behavior
        # rather than tweening a Control that's still owned by the Hand's HBoxContainer.
        queue_free()
        return
    pivot_offset = size / 2.0
    if get_parent() != ui_layer:
        reparent(ui_layer)

    var target_pos := global_position + Vector2(0, 220)
    var pile_button: Control = null
    var discard: Node = ui_layer.get_node_or_null("DiscardPileButton")
    if discard and discard is Control:
        pile_button = discard as Control
        target_pos = pile_button.global_position + pile_button.size / 2.0 - pivot_offset
    # The pile counts this card when it lands, not when the sweep starts (2026-09-24).
    var token := 0
    if pile_button is CardPileOpener:
        token = (pile_button as CardPileOpener).expect_arrival()

    var fly_time := 0.4
    var fly_tween := create_tween()
    fly_tween.tween_property(self, "global_position", target_pos, fly_time) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.parallel().tween_property(self, "scale", Vector2(0.15, 0.15), fly_time) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-25.0, 25.0)), fly_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    fly_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18) \
        .set_delay(fly_time - 0.18)
    if pile_button is CardPileOpener:
        fly_tween.tween_callback((pile_button as CardPileOpener).land_arrival.bind(token, true, 1.12))
    fly_tween.tween_callback(queue_free)

# In your CardUI class:
func apply_fan_rotation(angle: float) -> void:
    # Apply rotation to the card
    #rotation_degrees = angle
    print("test rotation")
    


func _on_gui_input(event: InputEvent) -> void:
    card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
    card_state_machine.on_mouse_entered()
    emit_signal("mouse_entered_card")


func _on_mouse_exited() -> void:
    card_state_machine.on_mouse_exited()
    emit_signal("mouse_exited_card")



func _set_card(value: Card) -> void:
    if not is_node_ready():
        await ready

    card = value
    _resize_description_panel()
    _apply_description(str(card.description))
    icon.texture = card.icon
    title.text = str(card.name)
    _apply_title_color()
    requirement_label.label_settings = REQUIREMENT_LABEL_SETTINGS
    rarity_gem.texture = RARITY_GEM_TEXTURES[card.rarity_tier]

    if card.requirement == Card.Requirement.NONE:
        requirement_panel.add_theme_stylebox_override("panel", NONE_STYLEBOX)
        requirement_label.label_settings = NO_REQUIREMENT_LABEL_SETTINGS
        requirement_label.text = "ANY"
    elif card.requirement == Card.Requirement.MAX:
        requirement_panel.add_theme_stylebox_override("panel", MAX_STYLEBOX)
        requirement_label.text = "Max %d" % card.requirement_number
    elif card.requirement == Card.Requirement.EVEN:
        requirement_panel.add_theme_stylebox_override("panel", EVEN_STYLEBOX)
        requirement_label.text = "Even"
    elif card.requirement == Card.Requirement.ODD:
        requirement_panel.add_theme_stylebox_override("panel", ODD_STYLEBOX)
        requirement_label.text = "Odd"
    elif card.requirement == Card.Requirement.RED:
        requirement_panel.add_theme_stylebox_override("panel", RED_STYLEBOX)
        requirement_label.text = "Red"
    elif card.requirement == Card.Requirement.EXACT:
        requirement_panel.add_theme_stylebox_override("panel", EXACT_STYLEBOX)
        requirement_label.text = "Exact %d" % card.requirement_number
    elif card.requirement == Card.Requirement.MIN:
        requirement_panel.add_theme_stylebox_override("panel", MIN_STYLEBOX)
        requirement_label.text = "Min %d" % card.requirement_number
    elif card.requirement == Card.Requirement.MULTIPLE:
        requirement_panel.add_theme_stylebox_override("panel", MULTIPLE_STYLEBOX)
        requirement_label.text = "Mult %d" % card.requirement_number
    if card.type == Card.Type.BLESSING:
        card_banner.add_theme_stylebox_override("panel", BLESSING_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", BLESSING_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", BLESSING_STYLEBOX)
        # Resync the glow cache same as the Celestial branch below - otherwise the first
        # playable-glow pass caches whatever stylebox was on CardFrame before this override
        # ran, and set_playable_visual() would keep re-applying that stale look at rest.
        _base_frame_stylebox = BLESSING_STYLEBOX
        _hot_frame_stylebox = null
        # Same as the Celestial branch: only re-style the "ANY" ribbon when there's truly no
        # requirement, so a Blessing WITH a real requirement (e.g. Berserk's Min 6) keeps its
        # requirement-specific ribbon. Without this, a requirement-less Blessing falls through
        # with the plain red NONE_STYLEBOX ribbon instead of matching its plum card body.
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", BLESSING_REQUIREMENT_NONE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", BLESSING_DESC_LABEL_SETTINGS.outline_color)

    if card.can_play_without_dice:

        description_panel.add_theme_stylebox_override("panel", CELESTIAL_DESC_STYLEBOX)
        card_banner.add_theme_stylebox_override("panel", CELESTIAL_BANNER_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", SUPPORT_STYLEBOX)
        # Keep the playable-glow cache in sync: set_playable_visual() lazily caches
        # whatever CardFrame's stylebox was on first call, which can happen before
        # this celestial override runs and would otherwise permanently re-apply the
        # stale maroon base every time the card returns to its resting glow state.
        _base_frame_stylebox = SUPPORT_STYLEBOX
        _hot_frame_stylebox = null
        # Only force the "no requirement" ribbon look when there truly is no requirement -
        # a Celestial card that DOES have a real requirement (e.g. From Nothing's Exact 0)
        # keeps its requirement-specific stylebox instead of being silently overwritten.
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", CELESTIAL_REQUIREMENT_NONE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", CELESTIAL_DESC_LABEL_SETTINGS.outline_color)

    # Hex runs LAST on purpose. Junk is Celestial (you must always be able to bin it
    # without spending a roll), so it would otherwise be repainted teal by the block above.
    # The type the enemy gave you has to outrank how the card happens to be played.
    if card.type == Card.Type.HEX:
        card_banner.add_theme_stylebox_override("panel", HEX_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", HEX_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", HEX_STYLEBOX)
        # Same glow-cache resync as the two branches above: set_playable_visual() lazily
        # caches whatever stylebox CardFrame had on its first call, and would otherwise
        # keep re-applying that stale look every time the card returns to rest.
        _base_frame_stylebox = HEX_STYLEBOX
        _hot_frame_stylebox = null
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", HEX_REQUIREMENT_NONE_STYLEBOX)
            requirement_label.label_settings = HEX_NO_REQUIREMENT_LABEL_SETTINGS
        description.add_theme_color_override("font_outline_color", HEX_DESC_LABEL_SETTINGS.outline_color)
    # Fixed bonus requirement logic
    if card.bonus_requirement == Card.Requirement.NONE:
        bonus_effect.hide()
        bonus_separator.hide()
    else:
        bonus_effect.show()
        bonus_separator.show()
        bonus_effect_label.text = card.get_colorized_description(str(card.bonus_description_text), 12)
        bonus_effect_texture.texture = card.bonus_description_icon

        if card.bonus_requirement == Card.Requirement.MAX:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MAX_STYLEBOX)
            bonus_requirement_label.text = "Max %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.EVEN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_EVEN_STYLEBOX)
            bonus_requirement_label.text = "Even"
        elif card.bonus_requirement == Card.Requirement.ODD:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_ODD_STYLEBOX)
            bonus_requirement_label.text = "Odd"
        elif card.bonus_requirement == Card.Requirement.RED:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_RED_STYLEBOX)
            bonus_requirement_label.text = "Red"
        elif card.bonus_requirement == Card.Requirement.EXACT:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_EXACT_STYLEBOX)
            bonus_requirement_label.text = "Exact %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.MIN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MIN_STYLEBOX)
            bonus_requirement_label.text = "Min %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.MULTIPLE:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MULTIPLE_STYLEBOX)
            bonus_requirement_label.text = "Mult %d" % card.bonus_requirement_number


# Green title on upgraded cards (STS2-style), plus a length-based font size step-down so long
# names stay on 1 line. Always duplicates the shared LabelSettings now that font_size can also
# vary per-card - mutating the shared resource in place would leak one card's size onto every
# other card using it (same trap as the color-only version this replaced).
func _apply_title_color() -> void:
    var settings := TITLE_LABEL_SETTINGS.duplicate()
    settings.font_size = title_font_size_for(card.name)
    # Hex wins over upgraded: the type identity has to survive whatever else the card is.
    # The title is the single most-read mark in the fan (the banner band is never covered by
    # the neighbouring card), so an ash title is what actually sells "not yours" at a glance.
    # This MUST go through the duplicated LabelSettings - a Label carrying one ignores
    # add_theme_color_override("font_color", ...) entirely, and silently.
    if card.type == Card.Type.HEX:
        settings.font_color = HEX_TITLE_COLOR
        settings.outline_color = HEX_TITLE_OUTLINE_COLOR
    elif card.upgraded:
        settings.font_color = UPGRADED_TITLE_COLOR
    title.label_settings = settings


func _set_playable(value: bool) -> void:
    playable = value
    if not playable:
        description.add_theme_color_override("default_color", Color.RED)
        icon.modulate = Color(1, 1, 1, 0.5)
    else:
        description.remove_theme_color_override("default_color")
        icon.modulate = Color(1, 1, 1, 1)
        


func _set_char_stats(value: CharacterStats) -> void:
    char_stats = value
    char_stats.stats_changed.connect(_on_char_stats_changed)


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
    if not targets.has(area):
        targets.append(area)


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
    targets.erase(area)


# Enemies can be freed (die mid-turn - e.g. a Magma dice AoE roll, or a kill while a card is
# still being aimed over them) while still recorded in `targets` from an earlier drag-over:
# area_exited only fires when a body/area physically LEAVES the detector, never when it's
# freed instead. Passing a freed Object into a typed Node parameter crashes at runtime
# ("previously freed" type error) rather than reading as null, so every read of `targets`
# prunes dead entries first instead of trusting the array as-is.
func _prune_stale_targets() -> void:
    for i in range(targets.size() - 1, -1, -1):
        if not is_instance_valid(targets[i]):
            targets.remove_at(i)


func _on_card_drag_or_aiming_started(used_card: CardUI) -> void:
    if used_card == self:
        return
    
    disabled = true


func _on_card_drag_or_aim_ended(_card: CardUI) -> void:
    disabled = false
    self.playable = char_stats.can_play_card(card)


func _on_char_stats_changed() -> void:
    self.playable = char_stats.can_play_card(card)

func _on_red_dice_rolled() -> void:
    # Only the card in socket ONE resolves off the signal. The charged-id LIST holds both
    # socketed cards (Red Cannon), so gating on it let whichever CardUI the signal reached
    # first win the roll: a self-targeted card in socket 2 played immediately and its
    # reset_charged_card tore down socket 1's card while it was still waiting to be aimed.
    # dice.gd hands socket 2 off itself once socket 1 is done.
    if card.instance_id != 0 and Global.red_roll_active_socket_id == card.instance_id:
        Global.dice_type = "red"
        # Reported BEFORE the card resolves, so Red matches Blue. On Blue, dice_rolled always
        # lands before you play anything, so per-roll Power effects (Dice Echo doubling
        # the turn's first roll, Sixth Gear, Metronome) are already banked by the time a card
        # reads Global.roll_value. Reporting after card.play() meant a self/AoE card socketed
        # on Red read the un-boosted number and the bonus arrived one beat too late to spend
        # (Julien, 2026-09-07: Block + Dice Echo + Blood Sword on a 5 paid 7 Block
        # instead of 12, and left 12 Power stranded in the bank). Aimed cards were already
        # correct - they sit in AIMING while this runs - so this only moves the non-aimed
        # branch onto the same footing.
        _report_red_roll()
        if card.target == Card.Target.SINGLE_ENEMY:
            print("single enemy card")
            # Force staying in AIMING state if no target selected
            card_state_machine._on_transition_requested(
                card_state_machine.current_state, 
                CardState.State.AIMING
            )
        else:
            print("Playing specific charged card: ", card.id)
            _prune_stale_targets()
            card.play(targets, char_stats, player_modifiers)
            # Same cleanup contract as card_released_state.gd's socketed-play branch: emit
            # while playing_red_card is still true so dice.gd flies the socket display to
            # the discard and drops its socketed_card_ui reference even when the card's own
            # apply_effects no-opped (whiffed requirement) and thus never emitted anything -
            # otherwise the socket keeps showing an already-played card and playing_red_card
            # stays stuck true for the rest of the turn.
            Events.reset_charged_card.emit()
            Global.playing_red_card = false
            queue_free()
        


    
   
    
# ⚠️ Exactly ONE dice_rolled per Red roll. dice.gd never emits it for Red, so this is what
# every per-roll relic actually hears - and with two cards socketed (Red Cannon) BOTH CardUIs
# reach this for a single roll. The token, armed by dice.gd just before red_dice_rolled, makes
# the first caller the only one that reports.
func _report_red_roll() -> void:
    if Global.red_roll_pending_report:
        Global.red_roll_pending_report = false
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)


# Red Cannon's second socket. dice.gd calls this once socket 1's card has fully resolved,
# instead of this CardUI reacting to red_dice_rolled on its own: the first card to handle that
# signal emits reset_charged_card, which clears Global.charged_card_instance_ids before the
# second CardUI's handler is dispatched - so the second card silently never played and its
# CardUI stayed hidden and disabled in the hand. The signal is NOT re-emitted for card 2
# (Blood Sword / House Money / Jackpot Pin / Effigy / Ruptured all listen to it and would
# fire twice on one roll), and red_roll_pending_report is deliberately left alone so the
# "exactly one dice_rolled per Red roll" rule still holds.
func begin_second_socket_play() -> void:
    if not card:
        return
    show()
    disabled = false
    if card.target == Card.Target.SINGLE_ENEMY:
        # Same forced aim socket 1 gets: the roll is already spent, so the card must be
        # played - card_aiming_state refuses to cancel while playing_red_card is true.
        card_state_machine._on_transition_requested(
                card_state_machine.current_state, CardState.State.AIMING)
        return
    _prune_stale_targets()
    play()
    Events.reset_charged_card.emit()
    Global.playing_red_card = false


func _setup_card_style() -> void:
    # Setup Card Background
    var bg_style = StyleBoxFlat.new()
    bg_style.bg_color = Color("#2A2040")  # Deep indigo background
    bg_style.corner_radius_top_left = 5
    bg_style.corner_radius_top_right = 5
    bg_style.corner_radius_bottom_left = 5
    bg_style.corner_radius_bottom_right = 5
    card_background.add_theme_stylebox_override("panel", bg_style)
    
    # Setup Card Frame
    var frame_style = StyleBoxFlat.new()
    frame_style.bg_color = Color("#2A2040")  # Same as background
    frame_style.border_color = Color("#D4AF37")  # Gold border
    frame_style.border_width_left = 2
    frame_style.border_width_top = 2
    frame_style.border_width_right = 2
    frame_style.border_width_bottom = 2
    frame_style.corner_radius_top_left = 5
    frame_style.corner_radius_top_right = 5
    frame_style.corner_radius_bottom_left = 5
    frame_style.corner_radius_bottom_right = 5
    panel.add_theme_stylebox_override("panel", frame_style)
    
    # Setup Card Banner
    var banner_style = StyleBoxFlat.new()
    banner_style.bg_color = Color("#4A2B7E")  # Royal purple
    banner_style.corner_radius_top_left = 5
    banner_style.corner_radius_top_right = 5
    card_banner.add_theme_stylebox_override("panel", banner_style)
    
    # Setup Card Title
    title.add_theme_color_override("font_color", Color("#FFD700"))  # Gold text
    title.add_theme_font_size_override("font_size", 14)
    
    # Setup Image Panel (assuming $CardBackground/CardFrame/Panel is the parent of CardArt)
    var image_panel = $CardBackground/CardFrame/Panel
    var image_style = StyleBoxFlat.new()
    image_style.bg_color = Color("#000000")  # Black background for image
    image_style.border_color = Color("#A67C00")  # Darker gold for inner frame
    image_style.border_width_left = 2
    image_style.border_width_top = 2
    image_style.border_width_right = 2
    image_style.border_width_bottom = 2
    image_panel.add_theme_stylebox_override("panel", image_style)
    
    # Setup Description
    var desc_style = StyleBoxFlat.new()
    desc_style.bg_color = Color("#F5F0DC")  # Parchment color
    desc_style.corner_radius_bottom_left = 5
    desc_style.corner_radius_bottom_right = 5
    # Assuming description is a Label inside a Panel, if it's just a Label:
    description.add_theme_color_override("font_color", Color("#3A2921"))  # Dark brown
    description.add_theme_font_size_override("font_size", 10)
    
    # Apply hover effects by updating your existing hover states
    # This uses your existing preloaded styleboxes but you can modify them
    # or create them programmatically like above


var tooltip_instance_requirement: Panel
var tooltip_instance_bonus: Panel
var tooltip_instances_tags: Array = []

# At the top of your CardUI, add these variables:
var _card_hover_id := 0

# Replace your _on_card_frame_mouse_entered:
func _on_card_frame_mouse_entered() -> void:
    # Invalidate any previous pending coroutine
    _card_hover_id += 1
    var my_id := _card_hover_id
    
    # Clean up any lingering tooltips immediately on new hover
    _cleanup_card_tooltips()
    
    await get_tree().create_timer(CARD_TOOLTIP_DELAY).timeout
    
    # Bail if a newer hover started, or mouse already left
    if my_id != _card_hover_id:
        return
    if not is_mouse_over_card():
        return
    
    var tooltips_to_show = []
    
    var requirement_string = Card.Requirement.keys()[card.requirement]
    if requirement_string != "NONE":
        tooltips_to_show.append(requirement_string)
    
    var bonus_requirement_string = Card.Requirement.keys()[card.bonus_requirement]
    if bonus_requirement_string != "NONE":
        tooltips_to_show.append(bonus_requirement_string)

    if card.type == Card.Type.BLESSING:
        tooltips_to_show.append("Blessing")

    if card.type == Card.Type.HEX:
        tooltips_to_show.append("Hex")

    # Kept even though Slander stopped being Celestial on 2026-09-02: leading with "needs no
    # Dice or Power to play" would frame an enemy gift as a perk, and it would be flatly wrong
    # now that binning one costs a roll. The Hex tooltip already carries the part that matters,
    # which is that playing it is how you get rid of it.
    if card.can_play_without_dice and card.type != Card.Type.HEX:
        tooltips_to_show.append("Celestial")

    # Tags, dice types mentioned in the text, and Power - all ordered by where they read in the
    # description, so the stack follows the sentence under the requirement ribbon. Shared with
    # card_menu_ui.gd so the two views can't drift (see KeywordColorizer for why each source is
    # included; neither dice types nor Power need an explicit tag).
    for keyword in KeywordColorizer.ordered_description_keywords(
            card.description, card.tags, str(card.bonus_description_text)):
        if not tooltips_to_show.has(keyword):
            tooltips_to_show.append(keyword)

    if tooltips_to_show.is_empty():
        return
    
    var start_y := Global.tooltip_column_y(global_position.y + (size.y / 2.0),
        tooltips_to_show.size(), TOOLTIP_HEIGHT, TOOLTIP_SPACING)
    # Flips to the card's left when there's no room on its right (a card in the deck view's
    # rightmost columns used to push this stack ~70px off screen). Flipping rather than
    # clamping matters here: a clamped column would sit on top of the card being read.
    var base_pos := Vector2(
        Global.tooltip_group_x(global_position.x, size.x, Global.TOOLTIP_PANEL_SIZE.x,
            TOOLTIP_OFFSET_X),
        start_y)
    
    # Capture hover_id for the lifetime timer closure below
    var captured_id := my_id
    
    for i in range(tooltips_to_show.size()):
        var tooltip = TooltipScene.instantiate()
        Global.add_tooltip(tooltip, self)
        var tooltip_panel = tooltip.get_node("Tooltip")
        tooltip_panel.get_tooltip_content(tooltips_to_show[i])
        
        var tooltip_pos = base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))
        tooltip_pos = tooltip_pos.round()
        tooltip_panel.show_tooltip(tooltip_pos)
        
        tooltip_instances_tags.append(tooltip)
    
    # Safety net: auto-destroy after 6 seconds even if mouse_exited never fires
    get_tree().create_timer(6.0).timeout.connect(func():
        # Only clean up if this is still the active hover session
        if captured_id == _card_hover_id:
            _cleanup_card_tooltips()
    )

# Replace your _on_card_frame_mouse_exited:
func _on_card_frame_mouse_exited() -> void:
    _card_hover_id += 1  # Invalidate any pending coroutine
    _cleanup_card_tooltips()

# Add this helper to centralize all tooltip cleanup:
func _cleanup_card_tooltips() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null
    
    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null
    
    for tooltip in tooltip_instances_tags:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    tooltip_instances_tags.clear()


func is_mouse_over_card() -> bool:
    return get_global_rect().has_point(get_global_mouse_position())

# Add a function to set playability visual
func set_playable_visual(state: PlayableGlow) -> void:
    if not _base_frame_stylebox:
        _base_frame_stylebox = card_frame.get_theme_stylebox("panel")
    current_glow_state = state
    match state:
        PlayableGlow.HOT, PlayableGlow.AVAILABLE:
            modulate = Color.WHITE
            var is_hot := state == PlayableGlow.HOT
            if not _hot_frame_stylebox:
                _hot_frame_stylebox = _base_frame_stylebox.duplicate()
            var border_width := GLOW_BORDER_WIDTH_HOT if is_hot else GLOW_BORDER_WIDTH_AVAILABLE
            _hot_frame_stylebox.border_width_left = border_width
            _hot_frame_stylebox.border_width_top = border_width
            _hot_frame_stylebox.border_width_right = border_width
            _hot_frame_stylebox.border_width_bottom = border_width
            # Keep expand_margin >= border_width so the thicker glow border only
            # bleeds outward past the card's edge instead of intruding inward into
            # the rect, where it would get painted over by RequirementPanel /
            # DescriptionPanel / BonusEffect (siblings drawn on top of CardFrame).
            _hot_frame_stylebox.expand_margin_left = border_width
            _hot_frame_stylebox.expand_margin_top = border_width
            _hot_frame_stylebox.expand_margin_right = border_width
            _hot_frame_stylebox.expand_margin_bottom = border_width
            _hot_frame_stylebox.shadow_size = GLOW_SHADOW_SIZE_HOT if is_hot else GLOW_SHADOW_SIZE_AVAILABLE
            var dice_color: Color = DicePalette.ACCENT.get(Global.dice_type, GLOW_DEFAULT_COLOR)
            _hot_frame_stylebox.shadow_color = Color(dice_color.r, dice_color.g, dice_color.b, GLOW_SHADOW_ALPHA_HOT if is_hot else GLOW_SHADOW_ALPHA_AVAILABLE)
            card_frame.add_theme_stylebox_override("panel", _hot_frame_stylebox)
            if is_hot:
                var current_alpha: float = _hot_frame_stylebox.border_color.a if (_glow_tween and _glow_tween.is_valid()) else GLOW_HOT_MIN_ALPHA
                _hot_frame_stylebox.border_color = Color(dice_color.r, dice_color.g, dice_color.b, current_alpha)
                if not (_glow_tween and _glow_tween.is_valid()):
                    _hot_frame_stylebox.border_color.a = GLOW_HOT_MIN_ALPHA
                    _glow_tween = create_tween().set_loops()
                    _glow_tween.tween_property(_hot_frame_stylebox, "border_color:a", GLOW_HOT_MAX_ALPHA, GLOW_PULSE_DURATION).set_trans(Tween.TRANS_SINE)
                    _glow_tween.tween_property(_hot_frame_stylebox, "border_color:a", GLOW_HOT_MIN_ALPHA, GLOW_PULSE_DURATION).set_trans(Tween.TRANS_SINE)
            else:
                if _glow_tween and _glow_tween.is_valid():
                    _glow_tween.kill()
                _hot_frame_stylebox.border_color = Color(dice_color.r, dice_color.g, dice_color.b, GLOW_AVAILABLE_ALPHA)
        PlayableGlow.NONE:
            if _glow_tween and _glow_tween.is_valid():
                _glow_tween.kill()
            card_frame.add_theme_stylebox_override("panel", _base_frame_stylebox)
            modulate = UNPLAYABLE_MODULATE_HAS_POWER if Global.roll_value > 0 else UNPLAYABLE_MODULATE_NO_POWER
        PlayableGlow.NEUTRAL:
            # Used while Inked: we can't tell if a card is playable (power is hidden), and
            # dimming it like a genuinely-blocked card is misleading since it's still playable.
            # Full brightness, no glow border - just the card's plain undecorated look.
            if _glow_tween and _glow_tween.is_valid():
                _glow_tween.kill()
            card_frame.add_theme_stylebox_override("panel", _base_frame_stylebox)
            modulate = Color.WHITE

# Re-applies whatever glow state was last set. Needed because other systems
# (e.g. card hover) can overwrite CardFrame's stylebox override directly.
func reapply_playable_visual() -> void:
    set_playable_visual(current_glow_state)

func _on_dice_rolled_update_description(_a = null, _b = null) -> void:
    # A played card keeps the number it was played at: the rest of the hand follows the dice, but
    # this one is on the stage showing what it just did.
    if _played:
        return
    if card and card.has_method("get_dynamic_description"):
        _prune_stale_targets()
        # Same single-target collapse Card.play() performs, so when two hitboxes overlap under
        # the cursor the previewed number is computed against the enemy that will actually be
        # hit - not just whichever body entered the aim probe first.
        var aim_candidates: Array[Node] = targets
        if card.is_single_targeted():
            aim_candidates = card.pick_single_target(targets)
        var aimed_target: Node = aim_candidates[0] if not aim_candidates.is_empty() else null
        # Same requirement scope Card.play() opens around apply_effects(): a relic that
        # boosts one gate's cards (Worm's Eye Lens -> Max) is read inside
        # ModifierHandler.get_modified_value, so without this the PREVIEW would quietly
        # print a smaller number than the card goes on to deal.
        Global.playing_card_requirement = card.requirement
        _apply_description(card.get_dynamic_description(player_modifiers, aimed_target))
        Global.playing_card_requirement = -1


# Single chokepoint for writing to the Description RichTextLabel: applies keyword coloring
# (Card.get_colorized_description(), driven off card.tags), re-centers the text via BBCode
# (RichTextLabel has no horizontal_alignment property the way Label did), and steps the font
# size down for long text so it doesn't overflow the fixed-height DescriptionPanel. Re-evaluated
# on every call, not just the initial set_card - dynamic descriptions can resolve "X" into a
# longer string than the static one (see get_dynamic_description call sites).
# Cards without a BonusEffect row reclaim the dead space below the panel (see DESC_PANEL_HEIGHT).
# Call before _apply_description: that measures against description_panel.size.y.
func _resize_description_panel() -> void:
    var h := DESC_PANEL_HEIGHT_WITH_BONUS if card.bonus_requirement != Card.Requirement.NONE \
        else DESC_PANEL_HEIGHT
    description_panel.offset_top = DESC_PANEL_TOP
    description_panel.offset_bottom = DESC_PANEL_TOP + h


func _apply_description(text: String) -> void:
    # Measured against the panel's real height rather than a char-count guess: the colorizer's
    # inline Power glyph and per-glyph width both move the wrap without moving the length.
    var available := minf(description_panel.size.y, DESC_FIT_BUDGET)
    for desc_font_size: int in DESC_FONT_SIZE_CANDIDATES:
        description.add_theme_font_size_override("normal_font_size", desc_font_size)
        # Power glyph rides 2px above the font size so it reads at cap height on every step-down.
        description.text = "[center]%s[/center]" % card.get_colorized_description(text, desc_font_size + 2)
        # RichTextLabel validates its wrap inside get_content_height(), so this reads true in the
        # same frame - no await (this runs per card in hand on every roll, it must stay sync).
        if description.get_content_height() <= available:
            return
