class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)
signal mouse_entered_card
signal mouse_exited_card

# At the top of your CardUI class, add these constants:
const TOOLTIP_OFFSET_X = 2  # Horizontal distance from card
const TOOLTIP_HEIGHT = 108    # Approximate height of each tooltip
const TOOLTIP_SPACING = 1     # Space between tooltips

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

# Played-card send-off polish (2026-07-17): an overbright "resolve flash" the instant the card
# is played, plus a sparse trail of dice-colored motes shed along the whole discard flight -
# same additive-radial recipe as the power orbs / impact particles, so the flight reads as the
# same magic moving through the world instead of a plain rectangle drifting away.
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
const RESOLVE_FLASH_COLOR := Color(1.65, 1.55, 1.15, 1.0)
const RESOLVE_FLASH_DECAY := 0.3
const TRAIL_MOTE_INTERVAL := 0.045
const TRAIL_MOTE_SIZE_MIN := 12.0  # bumped from 10-20 on Julien's "slightly increase the mote"
const TRAIL_MOTE_SIZE_MAX := 24.0
const TRAIL_MOTE_LIFETIME := 0.55
const TRAIL_MOTE_ALPHA := 0.85
# Motes render UNDER the card (z 90 vs the card's 100), so anything spawned near the card's
# center is invisible until the card moves off it - which fast attack arcs do, but a staged
# support card lingering at its pause point does not (Julien: "I can only see it on attack
# cards"). Scattering across most of the card's half-extents lets motes spill past the
# silhouette and stay visible even while the card idles on top of the emit point.
const TRAIL_MOTE_SCATTER_X := 34.0
const TRAIL_MOTE_SCATTER_Y := 46.0
# Exhaust-bound cards smolder out in ember tones right before the fade - a quick visual
# distinction between "went to discard" (plain fade) and "burned away forever".
const EXHAUST_EMBER_COLOR := Color(1.7, 0.65, 0.3, 1.0)
const EXHAUST_EMBER_TIME := 0.18

# STS2-style FIXED-SPOT staged play for EVERY played card (attacks and non-attacks alike).
# Julien picked this model explicitly (2026-07-18) after several release-relative versions all
# read as "up AND right": the sideways motion was the DRAG system placing the card at the cursor
# before the lift, so no vertical-only lift could remove it. The fix is to IGNORE the cursor
# entirely - the card always flies to ONE fixed presentation spot, holds there readable while
# the effect resolves, then streaks to the discard pile. Exactly like his STS2 recording (where
# the attack card also holds at the fixed spot while the slash lands). STAGE_HOLD_CENTER is the
# card's design-space CENTER at that spot: left of the dice interface (which sits center) so a
# held card doesn't cover it, mid-height so it clears both the top bar and the hand fan.
const STAGE_HOLD_CENTER := Vector2(470.0, 405.0)
const STAGE_ENTER_TIME := 0.3     # glide from wherever the card was grabbed to the fixed spot
const STAGE_HOLD_TIME := 0.24     # trimmed on Julien's feedback (0.5 -> 0.32 -> 0.24)
const STAGE_HOLD_SCALE := Vector2(1.12, 1.12)
# Exit: after the hold, the card streaks straight to the discard pile (bottom-right) and fades
# as it arrives. This rightward flight is the ONLY horizontal motion, and it's fine - Julien:
# "it flies to the discard pile and yes, of course that is to the right". The whole "go up" of
# the play is the vertical GLIDE before the hold; there is deliberately NO separate up-launch
# beat here anymore (an earlier one rose up-AND-slightly-right after the hold, which made the
# post-play motion read as "top-right" instead of a clean "up, then over to the pile").
const COMET_TO_PILE_TIME := 0.42
const COMET_TILT_DEG := 20.0      # a slight bank as it flies off - small on purpose, a bank not a flip
const COMET_MOTE_INTERVAL_MS := 20
const COMET_MOTE_SIZE_MIN := 15.0
const COMET_MOTE_SIZE_MAX := 26.0
const COMET_MOTE_ALPHA := 0.9
const COMET_MOTE_LIFETIME := 0.35

# Soft radial gradient + additive material for the flight trail, cached statically like
# card_particles.gd does - every play spawns motes, no point rebuilding the same texture.
static var _trail_texture: GradientTexture2D
static var _trail_material: CanvasItemMaterial


static func _get_trail_texture() -> GradientTexture2D:
    if _trail_texture:
        return _trail_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 32
    tex.height = 32
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    _trail_texture = tex
    return _trail_texture


static func _get_trail_material() -> CanvasItemMaterial:
    if _trail_material:
        return _trail_material
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _trail_material = mat
    return _trail_material

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
const DESC_FONT_SIZE_CANDIDATES: Array[int] = [12, 11, 10, 9, 8]

# DescriptionPanel is an INVISIBLE layout box: its stylebox bg_color is byte-identical to the card
# body's on the Celestial and Blessing variants, and differs by ~0.001 on the normal one (compare
# card_ui_description_panel_*.tres against card_ui_*.tres). So its height can grow into the 22px of
# dead space below it - y188..210, which only the BonusEffect row ever occupies - with zero visual
# change, buying long descriptions 1-2 font steps instead of making them pay for the side margins.
# 56 rather than the full 66: the text is vertically centred in the panel, so an over-tall panel
# lets a big block drift down until it crowds the card's bottom border - the same edge-crowding the
# 6px side margins just removed, on the other axis. Cards WITH a bonus effect keep 44 (BonusSeparator
# sits at y188). Must be applied BEFORE _apply_description(), which measures against this height.
const DESC_PANEL_TOP := 144.0
const DESC_PANEL_HEIGHT := 56.0
const DESC_PANEL_HEIGHT_WITH_BONUS := 44.0


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
    if _refusal_tween and _refusal_tween.is_valid():
        _refusal_tween.kill()
    card_background.position = Vector2.ZERO
    _refusal_tween = create_tween()
    for offset: float in [9.0, -7.0, 5.0, -3.0, 0.0]:
        _refusal_tween.tween_property(card_background, "position:x", offset, 0.045) \
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
    # Thrown-die landings bump fight/turn dice counters (Tsunami, Stampede...) - refresh
    # dynamic descriptions as each one lands so the numbers in hand never lag the counter.
    Events.dice_thrown_landed.connect(_on_dice_rolled_update_description)
    if card:
        card_instance_id = card.instance_id
    



func _input(event: InputEvent) -> void:
    card_state_machine.on_input(event)


func animate_to_position(new_position: Vector2, duration: float) -> void:
    tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "global_position", new_position, duration)


func play() -> void:
    if not card:
        return
    # Record where the card was played from, so effects like refuel can launch their "dice
    # fly back to the die" visual from the card itself. Set before card.play() because that's
    # what fires the effect (and the refuel signal) synchronously.
    Global.last_played_card_position = global_position + size / 2.0
    _prune_stale_targets()
    card.play(targets, char_stats, player_modifiers)
    _fly_to_discard_and_free()


# The played card's visual send-off (the effect already fired above; by play() time the card
# lives on the ui_layer, so it can move freely above the hand). One unified STS2-style
# choreography for every card type since 2026-07-18 - attacks, Block, support, AoE alike
# (aimed cards simply start their glide from near the enemy they were released on): glide to
# the presentation spot, hold readable, comet-streak into the discard pile. See the
# STAGE_*/COMET_* constants block for the full reasoning and tuning levers.
func _fly_to_discard_and_free() -> void:
    set_process_input(false)  # stop routing input into the now-discarding state machine
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    disabled = true
    z_index = 100
    if tween and tween.is_valid():
        tween.kill()  # stop any in-progress positioning tween (e.g. the aim move-up) from fighting the fly

    # Center the pivot for the whole send-off so the spin/shrink below act around the card's
    # middle instead of its top-left corner (the default pivot the fan/hover system leaves).
    # Safe to change here - the card has permanently left the hand by this point.
    pivot_offset = size / 2.0

    var target_pos := global_position + Vector2(0, 220)  # fallback if discard pile not found
    var pile_button: Control = null
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer:
        # A card played straight from the red-dice socket never went through the drag state
        # on its final play (dice.gd forces BASE->AIMING->RELEASED on the red roll), so
        # unlike every other play path it can still be a CHILD OF THE HAND here. It must
        # leave the hand NOW: card.play() already added its Card to the discard pile via
        # Events.card_played, so if End Turn fires during this ~1.3s fly-out,
        # player_handler.discard_cards() would iterate it as a hand card and add the SAME
        # Card object to the pile a second time - two copies drawn after the next reshuffle.
        if get_parent() != ui_layer:
            reparent(ui_layer)
        # Exhausting cards fly to the exhaust pile instead of discard - they never actually
        # land in the discard pile (see player_handler.gd::_on_card_played), so flying there
        # was a visual lie. should_exhaust() reflects the same synchronous check
        # player_handler.gd already made moments earlier via the same card.play() call.
        var pile_name := "ExhaustPileButton" if card.should_exhaust() else "DiscardPileButton"
        var discard: Node = ui_layer.get_node_or_null(pile_name)
        if discard and discard is Control:
            pile_button = discard as Control
            # Aim the card's visual CENTER at the button's center: with the centered pivot
            # above, the shrinking card's center stays at global_position + pivot_offset
            # (pivot_offset is in local unscaled coords, unaffected by the scale-down).
            target_pos = pile_button.global_position + pile_button.size / 2.0 - pivot_offset

    # Resolve flash: the card discharges the instant its effect lands - a quick overbright
    # pop on its own tween, so the sequential fly choreography below keeps its own timings.
    modulate = RESOLVE_FLASH_COLOR
    var flash_tween := create_tween()
    flash_tween.tween_property(self, "modulate", Color.WHITE, RESOLVE_FLASH_DECAY) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    var fly_tween := create_tween()

    # STS2-style present-and-hold for EVERY played card (see the STAGE_*/COMET_* constants
    # block) - attacks included, per Julien (his STS2 reference does the same: the attack card
    # holds at the fixed spot while the slash lands). Three beats: a decelerating GLIDE to the
    # ONE fixed presentation spot (ignoring wherever the cursor released the card - that cursor-
    # follow was the "up AND right" he kept seeing) while it grows and rights itself, a readable
    # HOLD while the effect resolves, then a fast comet EXIT into the discard pile. No separate
    # play-punch: the entrance grow to STAGE_HOLD_SCALE is the punch.
    # Glide to the fixed presentation spot (see the STAGE_HOLD_CENTER note). Decelerating cubic,
    # no overshoot.
    fly_tween.tween_property(self, "global_position", STAGE_HOLD_CENTER - pivot_offset, STAGE_ENTER_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    fly_tween.parallel().tween_property(self, "scale", STAGE_HOLD_SCALE, STAGE_ENTER_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    fly_tween.parallel().tween_property(self, "rotation", 0.0, STAGE_ENTER_TIME * 0.6) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    fly_tween.tween_interval(STAGE_HOLD_TIME)
    var pile_center := target_pos + pivot_offset
    # Exit: straight streak from the hold to the discard pile (bottom-right), accelerating
    # (EASE_IN), shrinking, with a slight bank. NO up-launch beat first - the "up" already
    # happened as the glide; this leg is purely the "then it flies to the pile" that Julien is
    # fine with. The card stays visible for the flight and fades as it nears the pile.
    fly_tween.tween_property(self, "global_position", pile_center - pivot_offset, COMET_TO_PILE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.parallel().tween_property(self, "scale", Vector2(0.12, 0.12), COMET_TO_PILE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(COMET_TILT_DEG), COMET_TO_PILE_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

    # Dense trail over the exit leg, on its own independent tween (a parallel of the position
    # tween would work too, but this keeps it uniform with the sparse wake below). Only reads
    # the card's live position and sheds motes - the position tween above owns movement.
    var comet_color := DicePalette.accent(Global.dice_type) * 1.6
    if ui_layer:
        var comet_trail := create_tween()
        comet_trail.tween_interval(STAGE_ENTER_TIME + STAGE_HOLD_TIME)
        comet_trail.tween_method(_comet_trail_step.bind(ui_layer, comet_color), 0.0, 1.0, COMET_TO_PILE_TIME)

    # Fade near the END of the flight so the card stays visible travelling to the pile.
    var fade_delay := STAGE_ENTER_TIME + STAGE_HOLD_TIME + COMET_TO_PILE_TIME - 0.18

    # Pile catch-punch on its OWN pile-owned tween, not chained on fly_tween: the card fades
    # out and queue_frees right as it reaches the pile, which would kill fly_tween and any
    # callback still queued on it. A pile-owned tween survives the card.
    if pile_button is CardPileOpener:
        var pb := pile_button as CardPileOpener
        var punch_tween := pb.create_tween()
        punch_tween.tween_interval(STAGE_ENTER_TIME + STAGE_HOLD_TIME + COMET_TO_PILE_TIME * 0.85)
        punch_tween.tween_callback(pb.receive_punch)

    # Sparse dice-colored wake shed at the card's position across the whole glide + hold + exit.
    # Motes own their own fade tween (mote.create_tween()) so they outlive this card's queue_free.
    if ui_layer:
        var trail_color := DicePalette.accent(Global.dice_type) * 1.6
        var trail_time := fade_delay + 0.2
        var trail_tween := create_tween()
        trail_tween.tween_method(_emit_flight_trail.bind(ui_layer, trail_color), 0.0, trail_time, trail_time)

    # Fade out near the end of the flight. queue_free waits for the fade so it isn't cut.
    # Exhaust-bound cards tint to ember tones just before fading - "burned", not "filed away".
    var fade_tween := create_tween()
    if card.should_exhaust():
        fade_tween.tween_interval(maxf(fade_delay - EXHAUST_EMBER_TIME, 0.0))
        fade_tween.tween_property(self, "modulate", EXHAUST_EMBER_COLOR, EXHAUST_EMBER_TIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    else:
        fade_tween.tween_interval(fade_delay)
    fade_tween.tween_property(self, "modulate:a", 0.0, 0.2) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fade_tween.tween_callback(queue_free)


# tween_method target for the flight trail above: `elapsed` sweeps 0 -> total flight time
# linearly, and a mote is dropped every TRAIL_MOTE_INTERVAL seconds of it at the card's
# current visual center. Kept sparse and small - it should read as a wake, not fireworks.
var _last_trail_emit := 0.0

func _emit_flight_trail(elapsed: float, layer: Node, color: Color) -> void:
    if elapsed - _last_trail_emit < TRAIL_MOTE_INTERVAL:
        return
    _last_trail_emit = elapsed
    if not is_instance_valid(layer):
        return
    _spawn_trail_mote(layer, color, TRAIL_MOTE_SIZE_MIN, TRAIL_MOTE_SIZE_MAX, TRAIL_MOTE_ALPHA, TRAIL_MOTE_LIFETIME)


# Dense-trail driver for the staged card's two-beat exit. Only sheds motes at the card's LIVE
# position (the two exit position tweens own movement) - `_t` is ignored. Motes are throttled on
# a REAL-TIME clock (ticks msec), not the tween's t: the exit accelerates (EASE_IN beat 2), so a
# t-based interval would clump motes at the slow launch and leave the fast pile-rush bare.
var _last_comet_mote_ms := 0

func _comet_trail_step(_t: float, layer: Node, color: Color) -> void:
    if not is_instance_valid(layer):
        return
    var now := Time.get_ticks_msec()
    if now - _last_comet_mote_ms < COMET_MOTE_INTERVAL_MS:
        return
    _last_comet_mote_ms = now
    _spawn_trail_mote(layer, color, COMET_MOTE_SIZE_MIN, COMET_MOTE_SIZE_MAX, COMET_MOTE_ALPHA, COMET_MOTE_LIFETIME)


# Shared mote factory for the sparse whole-flight wake AND the dense comet-exit streak.
func _spawn_trail_mote(layer: Node, color: Color, size_min: float, size_max: float, alpha: float, lifetime: float) -> void:
    var mote := TextureRect.new()
    mote.texture = _get_trail_texture()
    # Fixed 32x32 source texture - without EXPAND_IGNORE_SIZE it renders at native size no
    # matter what .size says (same TextureRect gotcha as the power orbs / refuel icons).
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mote.material = _get_trail_material()
    mote.modulate = color
    mote.modulate.a = alpha
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.z_index = 90  # just under the flying card itself (z 100)
    layer.add_child(mote)
    var s := randf_range(size_min, size_max)
    mote.size = Vector2(s, s)
    mote.pivot_offset = mote.size / 2.0
    # Scatter follows the card's current scale: full spread while the card is big/idling,
    # tightening into a point as it shrinks on the final arc - a fixed-size cloud around a
    # 15%-scale card would read as detached specks instead of a wake.
    var spread_x := TRAIL_MOTE_SCATTER_X * scale.x
    var spread_y := TRAIL_MOTE_SCATTER_Y * scale.y
    var center := global_position + pivot_offset + Vector2(
        randf_range(-spread_x, spread_x),
        randf_range(-spread_y, spread_y)
    )
    mote.global_position = center - mote.size / 2.0
    var mote_tween := mote.create_tween()
    mote_tween.tween_property(mote, "modulate:a", 0.0, lifetime) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    mote_tween.parallel().tween_property(mote, "scale", Vector2(0.3, 0.3), lifetime) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    mote_tween.parallel().tween_property(mote, "position", mote.position + Vector2(randf_range(-8.0, 8.0), randf_range(4.0, 14.0)), lifetime) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    mote_tween.tween_callback(mote.queue_free)


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
        fly_tween.tween_callback((pile_button as CardPileOpener).receive_punch.bind(1.12))
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
    if card.upgraded:
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
    # Check if this specific card instance is the charged card
    if Global.charged_card_instance_ids.has(card.instance_id):
        Global.dice_type = "red"
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
        
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)
        #Global.roll_value=0
        

    
   
    
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
    
    await get_tree().create_timer(1.0).timeout
    
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

    if card.can_play_without_dice:
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
    var available := description_panel.size.y
    for desc_font_size: int in DESC_FONT_SIZE_CANDIDATES:
        description.add_theme_font_size_override("normal_font_size", desc_font_size)
        # Power glyph rides 2px above the font size so it reads at cap height on every step-down.
        description.text = "[center]%s[/center]" % card.get_colorized_description(text, desc_font_size + 2)
        # RichTextLabel validates its wrap inside get_content_height(), so this reads true in the
        # same frame - no await (this runs per card in hand on every roll, it must stay sync).
        if description.get_content_height() <= available:
            return
