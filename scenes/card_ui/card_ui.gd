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
const RESOLVE_FLASH_COLOR := Color(1.65, 1.55, 1.15, 1.0)
const RESOLVE_FLASH_DECAY := 0.3
const TRAIL_MOTE_INTERVAL := 0.045
const TRAIL_MOTE_SIZE_MIN := 10.0
const TRAIL_MOTE_SIZE_MAX := 20.0
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
# the fixed-height DescriptionPanel at the default 12pt. Simple length-based step-down.
const DESC_FONT_SIZE_DEFAULT := 12
const DESC_FONT_SIZE_MEDIUM := 11
const DESC_FONT_SIZE_SMALL := 10
const DESC_LENGTH_MEDIUM_THRESHOLD := 60
const DESC_LENGTH_SMALL_THRESHOLD := 90


static func title_font_size_for(text: String) -> int:
    var font: Font = TITLE_LABEL_SETTINGS.font
    for size: int in TITLE_FONT_SIZE_CANDIDATES:
        if font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x <= TITLE_MAX_WIDTH:
            return size
    return TITLE_FONT_SIZE_CANDIDATES[-1]


static func description_font_size_for(text: String) -> int:
    var length := text.length()
    if length > DESC_LENGTH_SMALL_THRESHOLD:
        return DESC_FONT_SIZE_SMALL
    elif length > DESC_LENGTH_MEDIUM_THRESHOLD:
        return DESC_FONT_SIZE_MEDIUM
    return DESC_FONT_SIZE_DEFAULT

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


# Instead of vanishing instantly, the played card flies to the discard pile (Slay-the-Spire
# style) shrinking + spinning + fading on the way. The effect already fired above, so this
# is purely the visual send-off. By play() time the card lives on the ui_layer (the drag
# state reparented it there), so it can move freely above the hand.
#
# Single-targeted (aimed) cards and everything else take different paths, mirroring how the
# state machine itself already treats them differently (card_aiming_state.gd only runs for
# is_single_targeted() cards - everything else, including AoE attacks, never gets aimed and
# is released from wherever the drag happened to end, usually still near the hand):
#   - Single-targeted: unchanged - lifts from wherever it was released (near the enemy it was
#     aimed at) and arcs straight to discard. Julien confirmed this already reads well.
#   - Everything else (Block, support, AoE...): ALWAYS routes through a staging point near the
#     dice interface first, regardless of where it was actually released - like Slay the Spire
#     2, where non-attack cards visually resolve at the center before heading to discard.
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
    # pop + tiny scale punch, on separate tweens so the sequential fly choreography below
    # keeps its own timings. The punch fully settles (0.13s) before the earliest scale-down
    # in either branch starts (0.16s), so the two never fight over `scale`.
    modulate = RESOLVE_FLASH_COLOR
    var flash_tween := create_tween()
    flash_tween.tween_property(self, "modulate", Color.WHITE, RESOLVE_FLASH_DECAY) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var punch_tween := create_tween()
    punch_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.05) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    punch_tween.tween_property(self, "scale", Vector2.ONE, 0.08) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    var fly_tween := create_tween()
    var fade_delay: float

    if card.is_single_targeted():
        # Lift the card up first, then arc it down to the discard pile. Going straight from
        # the aim position (just above the hand) to the bottom-right pile looked flat/weird;
        # the little lift gives the toss an arc and reads like the card is "picked up" before
        # flying.
        var lift_pos := global_position + Vector2(0, -80)
        var lift_time := 0.16
        # Slower + floatier final leg to the discard pile (was 0.45s with an accelerating
        # TRANS_BACK/EASE_IN, read as "very fast" per Julien) - TRANS_SINE/EASE_IN_OUT drifts
        # rather than dashes.
        var arc_time := 0.7
        fly_tween.tween_property(self, "global_position", lift_pos, lift_time) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        fly_tween.tween_property(self, "global_position", target_pos, arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fly_tween.parallel().tween_property(self, "scale", Vector2(0.15, 0.15), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-35.0, 35.0)), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fade_delay = lift_time + arc_time - 0.2  # fade in during the arc's last ~0.2s
    else:
        var stage_pos := global_position  # fallback if dice interface not found
        var dice_interface := get_tree().get_first_node_in_group("dice_interface")
        if dice_interface and dice_interface is Control:
            # Offset above the dice interface's own center - floating at dead-center (roughly
            # the ROLL button/power number) sat too low/cramped against the dice UI.
            stage_pos = (dice_interface as Control).get_global_rect().get_center() + Vector2(0, -140)

        var stage_time := 0.22
        var hold_time := 0.08
        # Slower + floatier final leg to the discard pile (was 0.4s with an accelerating
        # TRANS_BACK/EASE_IN) - TRANS_SINE/EASE_IN_OUT drifts rather than dashes.
        var arc_time := 0.65
        fly_tween.tween_property(self, "global_position", stage_pos, stage_time) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-6.0, 6.0)), stage_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        fly_tween.tween_interval(hold_time)  # brief hold at the staging point before continuing on
        fly_tween.tween_property(self, "global_position", target_pos, arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fly_tween.parallel().tween_property(self, "scale", Vector2(0.15, 0.15), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-35.0, 35.0)), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fade_delay = stage_time + hold_time + arc_time - 0.2

    # The destination pile visibly "catches" the card the moment it arrives (the callback sits
    # after the final sequential position tween above, in both branches).
    if pile_button is CardPileOpener:
        fly_tween.tween_callback((pile_button as CardPileOpener).receive_punch)

    # Mote trail: shed sparks at the card's current position across the whole flight. Motes are
    # parented to the ui_layer and own their fade tween (mote.create_tween()), so they outlive
    # this card's queue_free below instead of vanishing with it.
    if ui_layer:
        var trail_color := DicePalette.accent(Global.dice_type) * 1.6
        var trail_time := fade_delay + 0.2
        var trail_tween := create_tween()
        trail_tween.tween_method(_emit_flight_trail.bind(ui_layer, trail_color), 0.0, trail_time, trail_time)

    # Fade out only near the END of the flight (separate tween), so the card stays visible
    # long enough to read that it's travelling to the discard pile - fading it across the
    # whole trip made the destination unclear. queue_free waits for the fade so it isn't cut.
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
    var mote := TextureRect.new()
    mote.texture = _get_trail_texture()
    # Fixed 32x32 source texture - without EXPAND_IGNORE_SIZE it renders at native size no
    # matter what .size says (same TextureRect gotcha as the power orbs / refuel icons).
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mote.material = _get_trail_material()
    mote.modulate = color
    mote.modulate.a = TRAIL_MOTE_ALPHA
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.z_index = 90  # just under the flying card itself (z 100)
    layer.add_child(mote)
    var s := randf_range(TRAIL_MOTE_SIZE_MIN, TRAIL_MOTE_SIZE_MAX)
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
    mote_tween.tween_property(mote, "modulate:a", 0.0, TRAIL_MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    mote_tween.parallel().tween_property(mote, "scale", Vector2(0.3, 0.3), TRAIL_MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    mote_tween.parallel().tween_property(mote, "position", mote.position + Vector2(randf_range(-8.0, 8.0), randf_range(4.0, 14.0)), TRAIL_MOTE_LIFETIME) \
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
        bonus_effect_label.text = card.get_colorized_description(str(card.bonus_description_text))
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
    if card.instance_id == Global.charged_card_instance_id:
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

    if card.tags != "":
        var tags_array = card.tags.split(",")
        for tag in tags_array:
            var trimmed_tag = tag.strip_edges()
            if trimmed_tag != "":
                tooltips_to_show.append(trimmed_tag)

    # Dice-type mentions don't need an explicit tag (see KeywordColorizer.colorize()) - detect
    # them straight from the description text so their tooltip still shows even on cards that
    # were never tagged with the dice type they mention.
    for dice_keyword in KeywordColorizer.find_dice_keywords_in_text(card.description):
        if not tooltips_to_show.has(dice_keyword):
            tooltips_to_show.append(dice_keyword)

    if tooltips_to_show.is_empty():
        return
    
    var total_tooltip_height = (tooltips_to_show.size() * TOOLTIP_HEIGHT) + ((tooltips_to_show.size() - 1) * TOOLTIP_SPACING)
    var card_center_y = global_position.y + (size.y / 2.0)
    var start_y = card_center_y - (total_tooltip_height / 2.0)
    
    var screen_height = get_viewport_rect().size.y
    var bottom_y = start_y + total_tooltip_height
    if bottom_y > screen_height - 20:
        start_y = screen_height - total_tooltip_height - 20
    if start_y < 20:
        start_y = 20
    
    var base_pos = Vector2(global_position.x + size.x + TOOLTIP_OFFSET_X, start_y)
    
    # Capture hover_id for the lifetime timer closure below
    var captured_id := my_id
    
    for i in range(tooltips_to_show.size()):
        var tooltip = TooltipScene.instantiate()
        get_tree().root.add_child(tooltip)
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
        var aimed_target: Node = targets[0] if not targets.is_empty() else null
        _apply_description(card.get_dynamic_description(player_modifiers, aimed_target))


# Single chokepoint for writing to the Description RichTextLabel: applies keyword coloring
# (Card.get_colorized_description(), driven off card.tags), re-centers the text via BBCode
# (RichTextLabel has no horizontal_alignment property the way Label did), and steps the font
# size down for long text so it doesn't overflow the fixed-height DescriptionPanel. Re-evaluated
# on every call, not just the initial set_card - dynamic descriptions can resolve "X" into a
# longer string than the static one (see get_dynamic_description call sites).
func _apply_description(text: String) -> void:
    description.add_theme_font_size_override("normal_font_size", description_font_size_for(text))
    description.text = "[center]%s[/center]" % card.get_colorized_description(text)
