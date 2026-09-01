class_name Enemy
extends Area2D

const ARROW_OFFSET := 5
# NameLabel now lives in its own CanvasLayer (see update_enemy()/_on_mouse_entered()
# below) so it can render above the hand of cards - a CanvasLayer boundary always wins
# over z_index, so as a plain child of Enemy it could never draw over BattleUI's Hand
# no matter what z_index it had. Width/center match the box it used to occupy locally;
# kept as constants here since the label is now positioned by hand in screen space
# instead of via Control offsets under Enemy's own transform.
const NAME_LABEL_WIDTH := 206.0
const NAME_LABEL_SPRITE_CENTER_X := 124.0
const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
const TARGET_HIGHLIGHT_OUTLINE_COLOR := Color(2.0, 1.7, 0.6, 1.0)
const TARGET_HIGHLIGHT_OUTLINE_THICKNESS := 3.0
const TARGET_HIGHLIGHT_FADE_IN_DURATION := 0.1

# Captured once at startup: the enemy's own outline ShaderMaterial. take_damage()'s
# hit-flash clears sprite_2d.material to null after the FIRST hit (see below), which
# would otherwise permanently lose this shader and silently break anything (like the
# target highlight) that depends on it existing.
var _base_sprite_material: ShaderMaterial
var _target_highlight_tween: Tween

# Hit-reaction state (knockback + squash). Rest values captured once per hit-burst so
# repeated hits in quick succession can't accumulate positional/scale drift.
var _hit_pos_tween: Tween
var _hit_squash_tween: Tween
var _hit_rest_position: Vector2
var _hit_rest_sprite_scale: Vector2
var _hit_reaction_active := false

# Directional hit smear (juice_audit P1a): a radial burst says "something happened", a
# smear says "force came FROM somewhere". Shared soft-streak texture + additive material,
# static so all enemies reuse one instance (same recipe as dice.gd's power orbs).
# 1, not 3: a hit under the old floor spawned NOTHING AT ALL, which is exactly the
# "1 damage on a red die and I literally see nothing even when focusing" case
# (Julien, 2026-08-26). Every real hit now draws a blade; only a true zero is skipped.
const HIT_SMEAR_MIN_DAMAGE := 1
static var _smear_texture: GradientTexture2D
static var _smear_material: CanvasItemMaterial


static func _get_smear_texture() -> GradientTexture2D:
    if _smear_texture:
        return _smear_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    _smear_texture = GradientTexture2D.new()
    _smear_texture.gradient = gradient
    _smear_texture.width = 64
    _smear_texture.height = 64
    _smear_texture.fill = GradientTexture2D.FILL_RADIAL
    _smear_texture.fill_from = Vector2(0.5, 0.5)
    _smear_texture.fill_to = Vector2(0.5, 0.0)
    return _smear_texture


static func _get_smear_material() -> CanvasItemMaterial:
    if _smear_material:
        return _smear_material
    _smear_material = CanvasItemMaterial.new()
    _smear_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    return _smear_material


# ===========================================================================
# SLASH VARIANT BOARD (2026-08-26) - see debug_slash_variants.gd
#
# Julien: "too fast, we can't really see it". Two structural reasons, both measured
# rather than guessed:
#   1. The slash MISSES ITS OWN FREEZE FRAME. DamageEffect calls take_damage() (which
#      spawns the slash) BEFORE Shaker.hit_stop_impact(). The CURRENT style then defers
#      0.055s of GAME time to dodge the white flash - under a 0.1x freeze that stretches
#      to ~0.3-0.5s of wall time, so the most photographable instant of every hit shows
#      flash + damage number and NO SLASH, and the streak plays its fastest motion during
#      the ramp-out. Anime does the opposite: the frozen frame IS the blade at extension.
#   2. There is no actual hold. The comment on _spawn_smear_streak claims sweep-then-HOLD,
#      but its fade tween starts at 35% of life while the sweep runs to 45% - alpha is
#      already dropping before the motion ends. Readable window: ~0.25s wide, ~0.16s core.
#   3. The "blade" is a stretched radial blob. It only reads as a cut WHILE MOVING, which
#      is why it had to be tuned fast. Slowing it down alone would leave a glowing smudge.
#
# STYLES (set Enemy.slash_style; CURRENT is the shipped one, untouched below):
#   CURRENT  - two travelling streaks + aimed cone. The baseline.
#   CRESCENT - suggestions 1+2 together: a real crescent blade (sharp convex edge, soft
#              trailing edge, tapered tips) that appears AT the impact instant, blooms
#              white-hot -> dice accent as the sprite flash decays, HOLDS dead still, then
#              dissolves tail-first along its own length. No travel at all.
#   WOUND    - suggestion 3: a cut mark etched ON the sprite (child of Sprite2D, so it
#              rides the squash/knockback), which persists ~0.5-0.8s before healing shut.
#              The readable artifact outlives the hit, so speed stops mattering.
#   FLURRY   - suggestion 4: the damage ladder expressed as CHOREOGRAPHY, not intensity.
#              Small hit = one crescent; medium = two crossing; big = a three-slash flurry
#              whose final blade is longer and holds longest. Built on CRESCENT's blade.
# ===========================================================================
enum SlashStyle { CURRENT, CRESCENT, WOUND, FLURRY }
# CRESCENT is the shipped default as of 2026-08-26 (Julien's pick off the variant board,
# for playtest). CURRENT is the pre-rework slash and is still intact below - switching back
# is one word here, and WOUND / FLURRY stay available for a second look.
static var slash_style: int = SlashStyle.CRESCENT

# --- Crescent blade (CRESCENT / FLURRY) ------------------------------------
# Wide canvas: the blade is a shallow arc, not a half-moon. A fast sword swing reads as a
# gently bowed line; a deep crescent reads as a logo.
const CRESCENT_TEX_W := 384
const CRESCENT_TEX_H := 176
# Arc geometry is shared by BOTH blade layers so their bows match exactly. The wide body
# and the white-hot core are two textures rather than one texture at two scales: scaling
# the same bitmap thinner would also flatten its bow, and a straight core inside a curved
# blade reads as two unrelated shapes (measured on the first render).
const CRESCENT_ARC_HALF_CHORD := 176.0
const CRESCENT_ARC_SAGITTA := 26.0
const CRESCENT_ARC_APEX_Y := 58.0
# Which way the arc bows on screen once rotated. -1 puts the concave side toward the
# attacker (upper-left), which is where a swing's pivot is.
const CRESCENT_BOW_SIGN := -1.0
# Front-loaded so it looks struck rather than popped, but short enough to land inside the
# freeze. This is the ONLY motion the blade ever has.
const CRESCENT_DRAW_ON := 0.05
const CRESCENT_BLOOM := 0.07
const CRESCENT_DISSOLVE := 0.30
# Hold per Shaker.Impact rung (indexed by the enum's int value). NOT a const Dictionary
# keyed on Shaker.Impact: Shaker is an autoload, so its enum is not a compile-time
# constant and a const dict keyed on it would not parse.
# Visible band width of the crescent bitmap in texture pixels (~2 sigma each side of the
# arc). Needed to turn a target ON-SCREEN thickness into a scale factor: dividing by the
# canvas height instead undersizes everything by ~3x, since most of the 176px canvas is
# empty space around the arc. (Cost one render to find.)
const CRESCENT_BAND_PX := 58.0
# Both ends moved on the same pass (Julien, 2026-08-26: "a bit longer, a bit more
# intense... always visible, and VERY visible on big hits, but never nothing"). The
# floor rose further than the ceiling: the bottom rungs were under the ~4px/10%
# perceptibility floor, so a chip read as an empty frame rather than as a small hit.
const CRESCENT_HOLD := [0.26, 0.32, 0.40, 0.50, 0.62]
const CRESCENT_LENGTH := [150.0, 180.0, 220.0, 265.0, 310.0]
# Thickness-to-length ratio, DELIBERATELY inverted against the length ladder: a short
# blade scaled proportionally is thin twice over and vanishes, so small hits get a
# stubbier, chunkier blade and big hits stay elegant. Keeps the low end above the
# visibility floor without flattening the ladder Julien wants to keep.
const CRESCENT_THICKNESS := [1.30, 1.18, 1.06, 0.99, 0.96]
const CRESCENT_ANGLE := 0.55

# --- Wound (WOUND) ---------------------------------------------------------
const WOUND_TEX_W := 384
const WOUND_TEX_H := 96
const WOUND_OPEN := 0.055
const WOUND_BLOOM := 0.1
const WOUND_HOLD := [0.3, 0.42, 0.58, 0.72, 0.86]
const WOUND_CLOSE := 0.22
const WOUND_THICKNESS_PX := [4.0, 5.0, 7.0, 9.0, 11.0]
const WOUND_MAX_CONCURRENT := 3
const WOUND_BAND_SIGMA := 3.4
# Visible band width in texture pixels (~4 sigma), used to convert a target on-screen
# thickness into a scale factor instead of hand-fudging a divisor.
const WOUND_BAND_PX := 13.6

# --- Flurry (FLURRY) -------------------------------------------------------
const FLURRY_COUNT := [1, 1, 2, 3, 3]
const FLURRY_STAGGER := 0.085
# Alternating so consecutive blades cross into an X instead of stacking on one line.
const FLURRY_ANGLES := [0.55, -0.46, 0.66]
const FLURRY_LENGTH_MUL := [0.86, 0.94, 1.16]

static var _crescent_texture: ImageTexture
static var _crescent_core_texture: ImageTexture
static var _wound_texture: ImageTexture
static var _wipe_shader_add: Shader
static var _wipe_shader_mix: Shader
var _wounds: Array[Node] = []


# Shallow-arc crescent with a SHARP convex edge and a soft concave tail, tapering to
# points at both tips. This is the shape fix that makes holding still possible: the old
# smear was a radial gradient stretched into a pill, which only reads as a cut while it
# is moving. A crescent reads as a swing even frozen.
static func _get_crescent_texture() -> ImageTexture:
    if _crescent_texture == null:
        # Fat on purpose. The first build used 4.5/13 and measured as a failure at game
        # scale: a ~10px line across a 120px body reads as a sword OUTLINE, not a cut
        # ("mass beats form", the same lesson the death fragments and the thrown-dice bash
        # both landed on). 7/22 puts ~35px of blade on a big hit.
        _crescent_texture = _build_crescent(7.0, 22.0, 0.55, 0.35)
    return _crescent_texture


static func _get_crescent_core_texture() -> ImageTexture:
    if _crescent_core_texture == null:
        _crescent_core_texture = _build_crescent(2.2, 4.2, 0.5, 0.3)
    return _crescent_core_texture


# Shallow-arc crescent: SHARP convex edge (the "edge"), soft concave tail (the "wake"),
# tapering to points at both tips. This is the shape fix that makes holding still possible
# - the old smear was a radial gradient stretched into a pill, which only reads as a cut
# while it is moving, which is exactly why it had to be tuned fast.
static func _build_crescent(sigma_lead: float, sigma_trail: float,
        taper_pow: float, alpha_pow: float) -> ImageTexture:
    var w := CRESCENT_TEX_W
    var h := CRESCENT_TEX_H
    var half_chord := CRESCENT_ARC_HALF_CHORD
    var sagitta := CRESCENT_ARC_SAGITTA
    var radius := (sagitta * sagitta + half_chord * half_chord) / (2.0 * sagitta)
    var cx := w * 0.5
    var cy := CRESCENT_ARC_APEX_Y + radius  # circle centre sits far below the canvas
    var theta_max := asin(half_chord / radius)
    var data := PackedByteArray()
    data.resize(w * h * 4)
    for y in h:
        for x in w:
            var px := x + 0.5 - cx
            var py := y + 0.5 - cy
            var sd := sqrt(px * px + py * py) - radius  # >0 = convex side
            var t := absf(atan2(px, -py)) / theta_max
            var a := 0.0
            if t < 1.0:
                var falloff := 1.0 - t * t
                var sigma := (sigma_lead if sd > 0.0 else sigma_trail) * pow(falloff, taper_pow)
                if sigma > 0.05:
                    a = exp(-0.5 * pow(sd / sigma, 2.0)) * pow(falloff, alpha_pow)
            var i := (y * w + x) * 4
            data[i] = 255
            data[i + 1] = 255
            data[i + 2] = 255
            data[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
    var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
    return ImageTexture.create_from_image(img)


# A cut, not a beam: near-black slit core with a bright rim, so it reads as broken cel
# linework on the body rather than a glow laid over it. RGB (not flat white) is the whole
# point - modulate multiplies, so the dark core survives tinting while the rim takes the
# dice accent. Much thinner and shorter than the crescent; it lives ON the sprite.
static func _get_wound_texture() -> ImageTexture:
    if _wound_texture:
        return _wound_texture
    var w := WOUND_TEX_W
    var h := WOUND_TEX_H
    var half_chord := 178.0
    # Very gentle: the wound is drawn thin and then stretched hard on the thickness axis
    # to hit a target pixel width, and that stretch multiplies the bow too. A texture-space
    # sagitta that looks right unstretched comes out as a banana on the body.
    var sagitta := 7.0
    var radius := (sagitta * sagitta + half_chord * half_chord) / (2.0 * sagitta)
    var cx := w * 0.5
    var cy := h * 0.5 - 6.0 + radius
    var theta_max := asin(half_chord / radius)
    var sigma := WOUND_BAND_SIGMA
    var data := PackedByteArray()
    data.resize(w * h * 4)
    for y in h:
        for x in w:
            var px := x + 0.5 - cx
            var py := y + 0.5 - cy
            var sd := sqrt(px * px + py * py) - radius
            var t := absf(atan2(px, -py)) / theta_max
            var a := 0.0
            var rim := 0.0
            if t < 1.0:
                var falloff := 1.0 - t * t
                var s := sigma * pow(falloff, 0.45)
                if s > 0.05:
                    a = exp(-0.5 * pow(sd / s, 2.0)) * pow(falloff, 0.3)
                    # Dark at the centreline, hot at the edges of the slit.
                    rim = clampf(absf(sd) / (s * 1.15), 0.0, 1.0)
            var lum := lerpf(0.05, 1.0, rim * rim)
            var i := (y * w + x) * 4
            var c := int(clampf(lum, 0.0, 1.0) * 255.0)
            data[i] = c
            data[i + 1] = c
            data[i + 2] = c
            data[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
    var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
    _wound_texture = ImageTexture.create_from_image(img)
    return _wound_texture


# Tail-first dissolve along the blade's own length. Built from a code string rather than a
# .gdshader file on purpose: no import step, so a stale worktree cache can never turn this
# into the parse error that kills the whole script (the preload trap in CLAUDE.md).
# Only COLOR.a is touched - in Godot 4 canvas_item fragment(), COLOR already arrives as
# texture * modulate, so multiplying alpha is the whole job and no MODULATE semantics are
# being relied on.
# A dice accent pulled toward white and gained up, for anything that has to stay BRIGHT
# while still reading as its type. Modulating straight by `accent` is a trap: cobalt blue
# is (0.24, 0.48, 1.0), so a mark born white at 2.2 and "bloomed" to accent*1.6 actually
# LOSES most of its luminance and sinks into the body art. Measured on the first wound
# render, where the mark vanished within ~6 frames of landing.
static func _hot_accent(accent: Color, toward_white: float, gain: float, alpha: float) -> Color:
    var c := accent.lerp(Color.WHITE, toward_white)
    return Color(c.r * gain, c.g * gain, c.b * gain, alpha)


static func _get_wipe_shader(additive: bool) -> Shader:
    if additive and _wipe_shader_add:
        return _wipe_shader_add
    if not additive and _wipe_shader_mix:
        return _wipe_shader_mix
    var src := "shader_type canvas_item;\n"
    if additive:
        src += "render_mode blend_add;\n"
    src += """
uniform float wipe : hint_range(0.0, 1.3) = 0.0;
uniform float wipe_soft : hint_range(0.01, 1.0) = 0.34;
void fragment() {
    COLOR.a *= smoothstep(wipe - wipe_soft, wipe, UV.x);
}
"""
    var sh := Shader.new()
    sh.code = src
    if additive:
        _wipe_shader_add = sh
    else:
        _wipe_shader_mix = sh
    return sh

@export var stats: EnemyStats : set = set_enemy_stats
@export var width: int 
@export var height: int
@export var initial_statuses: Array[Status] = []
# Per-instance turn-1 opener override, consumed by update_action(). Set it to the action_id
# of a node inside this enemy's AI scene to pin what it does on fight_turn 0 in THIS fight
# only. Empty (the default) = untouched behaviour, so every existing enemy is unaffected.
@export var forced_opener_action_id: String = ""
@export var sprite_y_offset: int = 0
@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@export var stats_ui_y_offset: int = 0
@export var intent_ui_y_offset: int = 0
@onready var arrow: Sprite2D = $Arrow
@onready var stats_ui: StatsUI = $StatsUI
@onready var name_label_layer: CanvasLayer = $NameLabelLayer
@onready var name_label: Label = $NameLabelLayer/NameLabel
@onready var intent_ui: IntentUI = $IntentUI
@export var status_handler_y_offset: int = 0
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler
@onready var animation_player: AnimationPlayer = $AnimationPlayer


var enemy_action_picker: EnemyActionPicker
var current_action: EnemyAction : set = set_current_action

var last_action: String = ""
var last_action_count: int = 0
var blocked_last_turn: bool = false

# Captured at set_enemy_stats() time, BEFORE create_instance()'s duplicate() call - a
# duplicated Resource doesn't reliably keep the original's resource_path, so deriving the
# fallback name from the file later (once `stats` only holds the duplicate) wouldn't work.
var _display_name := ""
# Source .tres basename, captured for the same reason - lets the idle-sway archetype tell
# the small octopus (octopus_enemy*) from the bigger one (bigger_octopus_enemy*), which
# share the "Kraken" display name and so can't be told apart by name alone.
var _source_stats_file := ""

# Local (unscaled) Y of the name label's box, computed in update_enemy() alongside
# stats_ui - converted to a screen-space CanvasLayer offset on hover, see
# _on_mouse_entered().
var _name_label_local_y: float = 0.0
# Local X of the name label, same idea - defaults to the legacy flat guess and gets
# overridden in update_enemy() if stats.content_center_x was actually measured.
var _name_label_local_x: float = NAME_LABEL_SPRITE_CENTER_X


func _ready() -> void:
    # Force a per-instance copy of the outline+sway material: resource_local_to_scene
    # already gives one per scene instantiation, but enemy_handler's duplicate() path
    # shouldn't be trusted to preserve that - shared params would sync every enemy's
    # sway phase (and target highlight) in a fight.
    sprite_2d.material = sprite_2d.material.duplicate()
    _base_sprite_material = sprite_2d.material as ShaderMaterial

    # Re-anchor the row every time anything it hangs off moves. Setting status_handler
    # .position does not re-trigger a sort, so none of these can loop.
    status_handler.sort_children.connect(_update_status_row_placement)
    # StatsUI is a Container: its HealthBar only reaches its final rect once the container
    # has sorted, and the row hangs off that bar.
    stats_ui.sort_children.connect(_update_status_row_placement)
    # The bar is nested one level deeper (StatsUI/Health/HealthBar), so StatsUI's own
    # sort_children can fire BEFORE the inner Health HBox has placed it. item_rect_changed
    # is the only signal that fires on the bar's FINAL rect - without it the row can be left
    # anchored to a one-frame-stale bar, which is a second way to look 'misplaced'.
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    if health_bar != null:
        health_bar.item_rect_changed.connect(_update_status_row_placement)

    # Per-enemy phase/speed jitter so multiple enemies on screen never breathe in
    # lockstep. Replaces the old AnimationPlayer phase-randomization trick - the idle
    # is now a shader-side deformation (see enemy.gdshader / _update_sway_params()),
    # the transform bob is retired and the "idle" animation no longer autoplays.
    _base_sprite_material.set_shader_parameter("sway_phase", randf() * 60.0)
    _base_sprite_material.set_shader_parameter("sway_speed", randf_range(0.85, 1.2))



func set_current_action(value: EnemyAction) -> void:
    current_action = value
    update_intent()


func set_enemy_stats(value: EnemyStats) -> void:
    _display_name = _compute_display_name(value)
    _source_stats_file = value.resource_path.get_file().get_basename()
    stats = value.create_instance()
    
    if not stats.stats_changed.is_connected(update_stats):
        stats.stats_changed.connect(update_stats)
        stats.stats_changed.connect(update_intent)
        Events.enemy_strength_changed.connect(update_intent)
        
    
    update_enemy()
    _apply_initial_statuses()  # <-- add this

func _apply_initial_statuses() -> void:
    if not is_inside_tree():
        await ready
    for status in initial_statuses:
        status_handler.add_status(status.duplicate())

func setup_ai() -> void:
    if enemy_action_picker:
        enemy_action_picker.queue_free()
        
    var new_action_picker := stats.ai.instantiate() as EnemyActionPicker
    add_child(new_action_picker)
    enemy_action_picker = new_action_picker
    enemy_action_picker.enemy = self


func update_stats() -> void:
    stats_ui.update_stats(stats)


func update_action() -> void:
    if not enemy_action_picker:
        return

    # Per-instance turn-1 override, set on the Enemy node inside a battles/*.tscn. Lets one
    # fight pin an enemy's opening beat without touching the AI scene every other fight using
    # that enemy shares - e.g. the Dice Mimic encounter forces its Satyr to open on the plain
    # attack so the mimic's steal isn't buried under a Weak landing the same turn.
    #
    # Deliberately ahead of the whole conditional/chance/fallback chain rather than inside the
    # picker: it has to win outright, and the picker's fallback ladder is load-bearing for
    # every other enemy.
    if Global.fight_turn == 0 and forced_opener_action_id != "":
        for child in enemy_action_picker.get_children():
            if child is EnemyAction and child.action_id == forced_opener_action_id:
                current_action = child
                return

    current_action = enemy_action_picker.get_action()


const MAX_ENEMY_WIDTH := 256.0
const MAX_ENEMY_HEIGHT := 256.0

# --- Why there is no End Turn clamp here any more (2026-08-25) -------------------------
# The enemy HUD stack (HP bar, then the status row hanging off its bottom edge) reaches
# down to y579 at worst across the 34 pool fights - tier_1_lurker_crab's Skeleton. The End
# Turn button used to start at y554, so on the 27 right-hand enemies whose bar sits past
# x1022 the row landed ON the button. Two generations of code tried to solve that by moving
# the ROW sideways; both broke attribution (see _update_status_row_placement below).
# It is now solved on the button's side instead: EndTurnButton was moved down to y581..643
# in battle.tscn (Julien, 2026-08-25), which clears every status row and still stops short
# of the discard pile's card art at y646.
# ⚠️ That leaves ~2px of slack at the top and ~3px at the bottom - the bottom-right corner
# of this screen is genuinely full. If you move EndTurnButton, resize a HP bar, or add an
# enemy whose bar sits lower than any current one, re-run debug_status_align.gd: it fails
# loudly on any row that touches the button, which is exactly what the old constants here
# could not do (they went stale in silence when the button moved on 2026-08-15).

# Screen-px gap between the HP bar's BOTTOM edge and the status row's TOP edge. Small and
# positive: the row must read as hanging off the bar, never as floating loose under it.
const STATUS_ROW_GAP := 2.0

# --- Enemy HUD scale (2026-07-24) ----------------------------------------------
# The HP bar + status row are drawn SMALLER than their authored size. This is not
# cosmetic - it is what makes a valid ground line exist at all. The stack hanging below
# the feet was: 32px bar container -> status at feet+24 -> 42px status extent = feet+66.
# The card fan's top is y562 at the leftmost enemy slot (x~750), so feet had to be <=496,
# while the painted floor in every background only starts at y~510 (act-2 library's
# furniture band pushes it to ~y505-510 on the right). Those two constraints did not
# overlap: NO feet value satisfied both, which is why status-vs-cards kept being
# whack-a-mole. At 0.7 the stack becomes ~44px, opening a real window (feet 512-525).
# stats_ui.tscn is SHARED with player.tscn, so this must stay a per-instance scale here
# and never an edit to that scene - the player's HP readout is deliberately left full size.
# Status icons stay FULL SIZE - they have to stay readable on the smallest enemy in the
# game (Julien 2026-07-24: 0.7 was unreadable). Budget is bought back by scaling the HP bar
# to the BODY instead of flat-shrinking it.
# DO NOT trim the Duration/Stacks label overhang in status_ui.tscn to save stack height:
# that label deliberately hangs off the icon's bottom-right corner ONTO THE BACKGROUND,
# which is what makes it legible. Pulling it inside the icon killed the contrast - and
# status_ui.tscn is shared with the PLAYER, so it broke the player's readout too.
const STATUS_UI_SCALE := 1.0
# HP bar scales with the enemy, STS-style: a big body gets a long bar, a small one a short
# bar. Flat-shrinking every bar made big solo enemies look weak ("hp bar too, looks really
# small"). Ratio is body content width vs the authored bar width, floored so a tiny Satyr's
# bar stays legible.
const BAR_SCALE_MIN := 0.55
const BAR_SCALE_MAX := 1.0
# Authored width of StatsUI (enemy.tscn offsets 17..223). Only a fallback for the pivot
# if `size` hasn't been laid out yet; the live `size.x` is preferred.
const STATS_UI_AUTHORED_WIDTH := 206.0
# Intent hangs off the real head (content top) with this gap, and shrinks on small bodies
# so it stops dwarfing them - folding the per-fight `scale` into the box had made intents
# on multi-fight enemies ~33% bigger overnight.
const INTENT_GAP := 20.0
const INTENT_SCALE_REFERENCE := 240.0
const INTENT_SCALE_MIN := 0.7
const INTENT_SCALE_MAX := 1.0

# Feet-planted idle sway (2026-07-23, replaces the whole-sprite AnimationPlayer bob).
# Amplitudes are in SCREEN pixels - _update_sway_params() converts to texture pixels
# per enemy. Tuned via the idle_sway_preview GIF A/B approved by Julien.
const SWAY_ARCHETYPES := {
    "organic": {"sway_px": 4.0, "head_px": 2.2, "head_lag": 0.8, "breathe_px": 2.8, "breathe_hz": 0.5, "drift_px": 0.0},
    "armored": {"sway_px": 1.8, "head_px": 1.0, "head_lag": 0.7, "breathe_px": 3.5, "breathe_hz": 0.25, "drift_px": 0.0},
    "floater": {"sway_px": 3.5, "head_px": 2.0, "head_lag": 1.1, "breathe_px": 1.0, "breathe_hz": 0.5, "drift_px": 3.0},
}
# Keyed on _display_name; anything not listed gets "organic". The floater archetype is
# NOT here - it's the SMALL octopus only, resolved by file in _update_sway_params()
# (the bigger octopus shares the "Kraken" name but stays grounded, per Julien 2026-07-23).
const SWAY_ARCHETYPE_BY_NAME := {
    "Marauder": "armored",
    "Temple Defender": "armored",
    "Ravager": "armored",
}

# Alpha-bbox of each enemy texture's actual content, cached per texture path -
# feet-anchoring (below) needs it once per texture, and get_image() on an
# imported texture decompresses (cheap enough once, wasteful per battle).
static var _content_rect_cache := {}
# Shared soft radial gradient used by every enemy's ground shadow.
static var _shadow_texture: GradientTexture2D

var _ground_shadow: Sprite2D


static func _get_shadow_texture() -> GradientTexture2D:
    if _shadow_texture == null:
        var gradient := Gradient.new()
        gradient.colors = PackedColorArray([
            Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.0)
        ])
        gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
        _shadow_texture = GradientTexture2D.new()
        _shadow_texture.gradient = gradient
        _shadow_texture.width = 256
        _shadow_texture.height = 256
        _shadow_texture.fill = GradientTexture2D.FILL_RADIAL
        _shadow_texture.fill_from = Vector2(0.5, 0.5)
        _shadow_texture.fill_to = Vector2(0.5, 0.0)
    return _shadow_texture


# Texture row where the enemy's BODY MASS starts, scanning down from the top - i.e. the
# first row at least HEAD_MASS_FRACTION as wide as the widest row. Thin props (Marauder's
# mace 50px, Temple Defender's crest 121px, Skeleton's scythe 76px) sit ABOVE this line and
# are deliberately ignored: anchoring the intent to the alpha bbox top parked it far above
# the actual head on those enemies ("intent is too high"). A Satyr's horns are only 14px, so
# this barely moves and their clearance is preserved.
const HEAD_MASS_FRACTION := 0.35
static var _head_line_cache := {}


# Returns how far DOWN from the content top the body mass starts, as a fraction (0..1) of
# the content height. Resolution-independent, so it survives any box/scale change.
# Scans a downscaled copy: get_pixel() from GDScript is slow, and a full-res sweep of every
# enemy texture would hitch on load. 96px is far more than enough for a 35% width threshold.
const HEAD_SCAN_MAX := 96


static func _get_head_line_fraction(tex: Texture2D) -> float:
    var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
    if _head_line_cache.has(key):
        return _head_line_cache[key]
    var result := 0.0
    var img := tex.get_image()
    if img != null:
        var used := img.get_used_rect()
        if used.size.x > 0 and used.size.y > 0:
            var small := img.get_region(used)
            var w := small.get_width()
            var h := small.get_height()
            var f: float = float(HEAD_SCAN_MAX) / float(maxi(w, h))
            if f < 1.0:
                small.resize(maxi(1, int(w * f)), maxi(1, int(h * f)), Image.INTERPOLATE_NEAREST)
                w = small.get_width()
                h = small.get_height()
            var widths := PackedInt32Array()
            widths.resize(h)
            var widest := 0
            for y in range(h):
                var count := 0
                for x in range(w):
                    if small.get_pixel(x, y).a > 0.0:
                        count += 1
                widths[y] = count
                widest = maxi(widest, count)
            for y in range(h):
                if widths[y] >= HEAD_MASS_FRACTION * widest:
                    result = float(y) / float(h)
                    break
    _head_line_cache[key] = result
    return result


static func _get_content_rect(tex: Texture2D) -> Rect2:
    var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
    if _content_rect_cache.has(key):
        return _content_rect_cache[key]
    var rect := Rect2(Vector2.ZERO, tex.get_size())
    var img := tex.get_image()
    if img != null:
        var used := img.get_used_rect()
        if used.size.x > 0 and used.size.y > 0:
            rect = Rect2(used)
    _content_rect_cache[key] = rect
    return rect


# Fallback anchor for the status row, in Enemy-local space. Only used on the frames before
# StatsUI has laid its HealthBar out - the real anchor is read off the live bar below.
var _status_row_fallback_x: float = 17.0
var _status_row_fallback_y: float = 0.0


# --- "Right below the HP bar", by construction (2026-08-25) ---------------------------
# THE contract, and the only one: the status row's top-left corner sits at the VISIBLE red
# bar's bottom-left corner, plus STATUS_ROW_GAP. BOTH axes are read off HealthBar's live
# global transform, so the row cannot drift no matter what scales the bar (BAR_SCALE_MIN..
# MAX sizes it to the body) or the enemy (per-fight Enemy.scale in multi-body comps).
#
# Anchored to HealthBar, never to StatsUI: StatsUI is a 206px HBoxContainer that centres a
# 175px HealthBar inside itself, so its own left edge sits ~11px left of the bar the player
# actually sees.
#
# Read through get_global_transform() rather than get_global_rect(). Both are correct in
# Godot 4.3 - get_global_rect() DOES fold in ancestor scale, measured identical to the
# transform on a bar_scale'd 0.55 Satyr - but the transform says so explicitly, which
# matters on a node whose size and scale come from two different places.
#
# The old vertical formula (StatsUI's AUTHORED height minus a flat 8px) is gone for the same
# reason: the 8 did not scale with bar_scale, so the row's overlap into the bar grew from
# 2px on a full-size bar to 4.7px on a small Satyr's. Reading the bar's real bottom edge
# makes the gap identical on every enemy in the game.
func _update_status_row_placement() -> void:
    if status_handler == null or stats_ui == null:
        return
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    if health_bar == null or health_bar.size.x <= 0.0:
        status_handler.position = Vector2(_status_row_fallback_x, _status_row_fallback_y)
        return
    var xf := health_bar.get_global_transform()
    var c0 := xf * Vector2.ZERO
    var c1 := xf * health_bar.size
    # Canvas space is 1:1 with the 1280x720 design rect here (the battle camera is identity),
    # so STATUS_ROW_GAP is a real screen-pixel gap; to_local() divides it back through
    # Enemy.scale for us.
    var anchor := Vector2(minf(c0.x, c1.x), maxf(c0.y, c1.y) + STATUS_ROW_GAP)
    status_handler.position = to_local(anchor)


func update_enemy() -> void:
    if not stats is Stats:
        return
    if not is_inside_tree():
        await ready

    sprite_2d.texture = stats.art
    sprite_2d.modulate = Color(1, 1, 1, 1)

    var tex_size = sprite_2d.texture.get_size()

    # Fallback defaults if not set in inspector
    var target_width := width if width > 0 else 256
    var target_height := height if height > 0 else 256

    if tex_size.x > 0 and tex_size.y > 0:
        var width_scale = target_width / tex_size.x
        var height_scale = target_height / tex_size.y
        var final_scale = min(width_scale, height_scale)
        sprite_2d.scale = Vector2(final_scale, final_scale)

        var sprite_display_height = tex_size.y * final_scale

        # --- Feet-anchoring (2026-07-19, re-fixed 2026-07-20) --------------------
        # Put the art's CONTENT bottom (alpha bbox) on the BOX bottom - the ground line
        # the level designer tuned position.y against (they placed enemies assuming the
        # sprite fills its box). For a padding-free texture this is a no-op (content
        # bottom already = box bottom); for one with bottom padding it pushes the sprite
        # down so the *visible* feet reach the ground instead of floating above it.
        # feet_line_y is the single source of truth for "where the feet are" - the sprite,
        # the HP bar, the status row and the shadow all derive from it below.
        var content := _get_content_rect(sprite_2d.texture)
        var content_bottom_from_center: float = (content.end.y - tex_size.y / 2.0) * final_scale
        var feet_line_y: float = sprite_y_offset + sprite_display_height / 2.0
        sprite_2d.position.y = feet_line_y - content_bottom_from_center

        # --- HP bar / status / name hang from the VISIBLE FEET, never above them ------
        # THIS is the fix for the endless "sprite overlaps its own HP bar" saga. The bar
        # used to be computed from the box + per-fight stats_ui_y_offset, and a NEGATIVE
        # offset (Marauder -24, Vortex -10, Lurker+Crab -8) yanked it UP into the body.
        # Now the bar sits AT the feet line; the offsets survive only as DOWNWARD nudges
        # (maxf(.,0)) so the bar can never ride up into the sprite no matter what any
        # present-or-future per-fight tuning says. Enemies with a 0 offset are unchanged.
        # --- HP bar sized to the BODY (STS-style) --------------------------------------
        # Scale the bar around its own horizontal CENTRE with the top edge pinned:
        # pivot (w/2, 0) keeps the visual top at position.y and the centre x where it
        # already was, so every feet/centring calculation stays valid. With the default
        # (0,0) pivot the bar would shrink left-aligned and slide ~31px off the body.
        var content_width: float = content.size.x * final_scale
        var bar_scale: float = clampf(content_width / STATS_UI_AUTHORED_WIDTH,
            BAR_SCALE_MIN, BAR_SCALE_MAX)
        var stats_ui_width: float = stats_ui.size.x if stats_ui.size.x > 0.0 else STATS_UI_AUTHORED_WIDTH
        stats_ui.pivot_offset = Vector2(stats_ui_width / 2.0, 0.0)
        stats_ui.scale = Vector2(bar_scale, bar_scale)

        stats_ui.position.y = feet_line_y + maxf(stats_ui_y_offset, 0.0)
        # `size.y` is the AUTHORED height (32) - scaling doesn't change it, so the drawn
        # height must be applied by hand or the status row hangs too low.
        var stats_ui_drawn_height: float = stats_ui.size.y * bar_scale
        # Fallback anchor only: _update_status_row_placement() overrides both axes off the live
        # HealthBar as soon as StatsUI has sorted. Kept so the row is never at (0,0) on the
        # first frame, and so per-fight status_handler_y_offset nudges still land somewhere.
        var fallback_nudge: float = maxf(status_handler_y_offset, 0.0)
        _status_row_fallback_y = stats_ui.position.y + stats_ui_drawn_height - 8.0 + fallback_nudge
        _status_row_fallback_x = stats_ui.position.x + (stats_ui_width / 2.0) * (1.0 - bar_scale)
        _update_status_row_placement()
        _name_label_local_y = stats_ui.position.y + stats_ui_drawn_height + 4

        # --- Intent: anchored to the real HEAD, and scaled to the body ------------------
        # Anchored to the body-mass line rather than the alpha bbox top, so a tall thin prop
        # (mace, crest, scythe) no longer pushes the intent way above the head. Pivot is the
        # box's bottom-centre, so the drawn bottom stays at position.y + size.y under scale.
        var content_height: float = content.size.y * final_scale
        var intent_scale: float = clampf(content_height / INTENT_SCALE_REFERENCE,
            INTENT_SCALE_MIN, INTENT_SCALE_MAX)
        intent_ui.scale = Vector2(intent_scale, intent_scale)
        intent_ui.pivot_offset = Vector2(intent_ui.size.x / 2.0, intent_ui.size.y)
        var head_frac: float = _get_head_line_fraction(sprite_2d.texture)
        var head_line_y: float = feet_line_y - content_height * (1.0 - head_frac)
        intent_ui.position.y = head_line_y - INTENT_GAP - intent_ui.size.y - intent_ui_y_offset

        # sprite_2d.position.x is a fixed baseline baked into enemy.tscn's template (124,
        # never reassigned by code, same value NAME_LABEL_SPRITE_CENTER_X was hand-copied
        # from) - has to be added back in, not replaced, or the label loses that baseline
        # entirely and drifts hard left. Only the content-fraction term is enemy-specific.
        _name_label_local_x = sprite_2d.position.x
        if stats.content_center_x >= 0.0:
            _name_label_local_x += (stats.content_center_x - 0.5) * tex_size.x * final_scale

        # --- Ground shadow (2026-07-19) ------------------------------------------
        # Soft ellipse at the feet line, STS-style: sells grounding even for art drawn
        # in a mid-leap/diagonal pose (Lava Hound) that no offset can fix, and makes
        # deliberate floaters read as "hovering above their shadow" instead of just
        # misplaced. Child of the Enemy root, NOT SpriteRoot - hit squash/knockback
        # animate the sprite, and the shadow must stay put while the body moves above
        # it (the idle itself is a shader deformation that never moves the feet).
        if _ground_shadow == null:
            _ground_shadow = Sprite2D.new()
            _ground_shadow.texture = _get_shadow_texture()
            add_child(_ground_shadow)
            move_child(_ground_shadow, 0)  # draw behind SpriteRoot
        var content_center_x_local: float = sprite_2d.position.x \
            + (content.get_center().x - tex_size.x / 2.0) * final_scale
        var shadow_width: float = content.size.x * final_scale * 0.82
        # Just below the feet (feet at feet_line_y), so it peeks out around them.
        _ground_shadow.position = Vector2(content_center_x_local, feet_line_y + 5.0)
        _ground_shadow.scale = Vector2(shadow_width / 256.0, shadow_width * 0.24 / 256.0)

        _update_sway_params(final_scale)
    else:
        sprite_2d.position.y = sprite_y_offset

    # Multi-enemy battle scenes set `scale` on the Enemy root to fit several bodies. The
    # StatusHandler inherits that shrink; counter-scale it so status icons stay a constant
    # size no matter the enemy's own scale - then apply STATUS_UI_SCALE on top so that
    # constant size is the new, smaller one (see the HUD-scale note above).
    if scale.x != 0 and scale.y != 0:
        status_handler.scale = Vector2(STATUS_UI_SCALE / scale.x, STATUS_UI_SCALE / scale.y)
    arrow.position = Vector2.RIGHT * (sprite_2d.get_rect().size.x * sprite_2d.scale.x / 2 + ARROW_OFFSET)
    setup_ai()
    update_stats()
    setup_ai()
    update_stats()

# Push the feet-planted idle-sway params to this enemy's material (enemy.gdshader).
# Called from update_enemy() so a texture/scale change (the act-2 reskin re-runs it)
# re-derives the pixel conversion; the per-enemy phase/speed jitter is set once in
# _ready(). Amplitudes are tuned in SCREEN px - divide by every scale between texture
# and screen (the sprite's final_scale, then the per-fight Enemy root scale).
func _update_sway_params(final_scale: float) -> void:
    if _base_sprite_material == null:
        # First update_enemy() awaits `ready`, which fires after _ready(), so this only
        # trips if the material was externally cleared - nothing to configure then.
        return
    var archetype: String = SWAY_ARCHETYPE_BY_NAME.get(_display_name, "organic")
    # Floater = the SMALL octopus ONLY (Julien 2026-07-23). Small octopus .tres files
    # begin with "octopus_enemy", bigger ones with "bigger_octopus_enemy", and both share
    # the "Kraken" display name in act 1 - so name alone can't split them, hence the file
    # check. Gating on the "Kraken" name too keeps the act-2 small-octopus reskin (renamed
    # Deepling, a grounded rock octopus) organic.
    if _display_name == "Kraken" and _source_stats_file.begins_with("octopus_enemy"):
        archetype = "floater"
    var preset: Dictionary = SWAY_ARCHETYPES[archetype]
    var to_tex := 1.0 / maxf(final_scale * scale.x, 0.001)
    _base_sprite_material.set_shader_parameter("sway_px", preset["sway_px"] * to_tex)
    _base_sprite_material.set_shader_parameter("head_px", preset["head_px"] * to_tex)
    _base_sprite_material.set_shader_parameter("head_lag", preset["head_lag"])
    _base_sprite_material.set_shader_parameter("breathe_px", preset["breathe_px"] * to_tex)
    _base_sprite_material.set_shader_parameter("breathe_hz", preset["breathe_hz"])
    _base_sprite_material.set_shader_parameter("drift_px", preset["drift_px"] * to_tex)
    _base_sprite_material.set_shader_parameter("margin_px", 6.0 * to_tex)


func update_intent() -> void:
    if current_action:
        current_action.update_intent_text()
        intent_ui.update_intent(current_action.intent)


func do_turn() -> void:
    stats.block = 0

    if not current_action:
        return

    # Thorned Plate needs to know who threw the punch: the damage pipeline only carries an
    # amount, never a source. Set around the action and cleared after, so anything happening
    # outside an enemy's turn (a card backfiring on the player) leaves it null.
    Global.acting_enemy = self
    current_action.perform_action()
    Global.acting_enemy = null

    # Track last action
    if last_action == current_action.action_id:
        last_action_count += 1
    else:
        last_action = current_action.action_id
        last_action_count = 1


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
    if stats.health <= 0:
        return

    sprite_2d.material = WHITE_SPRITE_MATERIAL
    var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
    # Same post-block display rule as Player.take_damage: the popup number is what the
    # HP bar actually loses, so hitting a blocking enemy reads honestly too.
    Global.blocked_to_display = mini(stats.block, modified_damage)
    Global.damage_to_display = modified_damage - Global.blocked_to_display

    _play_hit_reaction()
    _spawn_hit_smear(modified_damage)
    stats.take_damage(modified_damage)

    # Short, sharp white flash. Was 0.17s, which left the enemy a featureless white
    # silhouette long enough to erase its art and mask the hit reaction underneath.
    # Decoupled from the death trigger below so the flash length is independent of it.
    var flash_tween := create_tween()
    flash_tween.tween_interval(0.06)
    flash_tween.tween_callback(
        func():
            if stats.health <= 0:
                # Drop the outline shader entirely rather than restoring it:
                # its fragment() ignores incoming modulate/alpha, so the
                # death-fade below would have no visible effect on this
                # sprite while it's assigned. The enemy is about to be
                # freed anyway, so it no longer needs highlight capability.
                sprite_2d.material = null
                Global.run_stat_enemies_slain += 1
                Events.enemy_died.emit(self)
                _play_death_sequence()
            else:
                sprite_2d.material = _base_sprite_material
    )


# ---------------------------------------------------------------------------
# Death sequence (2026-08-15, STS2 audit 4.1 - "Dice Odyssey enemy death v1")
#
# Was: one tween fading modulate:a to 0 over 0.4s, then queue_free. No particles, no
# sound, no wait for anything - the single most clippable beat in the game was also the
# cheapest thing in it.
#
# The shape is taken from the reference and adapted to what we can build without Spine:
#   - the body half-vanishes IMMEDIATELY (a ghost), it does not slowly dim
#   - fragments peel off CONTINUOUSLY across the whole window rather than puffing once
#   - fragments drift UP (negative gravity) and tumble, so it reads as dissolving away
#     rather than as debris falling
#   - the corpse is held long enough to be seen, but the hit reaction gets to play first
#
# Deliberately NOT included (that's audit stage 2, post-launch): the two-frequency-noise
# dissolve shader on a SubViewport snapshot. Our flat cel art with hard outlines would
# dissolve *better* than their painted art, but it needs a snapshot pipeline we don't have.
# ---------------------------------------------------------------------------

# Let the knockback/squash hit reaction read before the body starts ghosting. The
# reference explicitly waits for the current animation to finish before dissolving;
# ours used to start fading 0.06s after the hit, cutting its own reaction off.
const DEATH_PRE_DELAY := 0.15
# The body drops to a ghost almost instantly instead of dimming gradually - the reference
# holds the corpse at alpha 0.467 for the entire dissolve. Reading "it's dead" has to be
# instant; the rest of the sequence is the flourish, not the information.
# 0.40 rather than the reference's 0.467: our cel art carries heavy near-black outlines,
# which keep reading as solid at an alpha where their painted art already looks like a
# ghost. Verified on rendered frames, not assumed.
const DEATH_GHOST_ALPHA := 0.4
const DEATH_GHOST_FADE := 0.1
const DEATH_HOLD := 0.55
const DEATH_FADE_OUT := 0.5
# 60, not the 26 this shipped with first: at 26 the render showed about five chips over the
# whole body, which reads as "a few sparks happened near a corpse" rather than "the body is
# coming apart". Same lesson as the thrown-dice bash and the slash smear - MASS beats form;
# the eye reads quantity long before it reads shape. (The reference uses 500 for a much
# larger sprite.)
const DEATH_FRAGMENT_COUNT := 60
const DEATH_FRAGMENT_LIFETIME := 0.95
# PLACEHOLDER, same convention as dice.gd's LAND_THUD_SOUND - a low, final body-drop.
# Swap freely; nothing else uses it.
const DEATH_SOUND := preload("res://sfx/186658__shmeepz__timpani-1.wav")

static var _fragment_texture: ImageTexture
static var _fragment_scale_curve: Curve


func _play_death_sequence() -> void:
    # Retire the body from every gameplay query the INSTANT it dies, before the animation
    # is given any time at all. This is the load-bearing part of making the death longer:
    # ~20 call sites (AoE cards, thrown-die retargeting, several relics) find their targets
    # via get_nodes_in_group("enemies"), and the aim/hover path goes through this Area2D.
    # A corpse that lingered 1.3s in the tree while still in the group would silently eat
    # AoE damage, absorb retargeted dice, and stay hoverable. Leaving the group fixes every
    # one of those sites at once; killing the Area2D fixes targeting and hover.
    remove_from_group("enemies")
    set_deferred("monitoring", false)
    set_deferred("monitorable", false)
    set_deferred("input_pickable", false)

    # The reference clears the creature's UI before the dissolve, and it's right: a health
    # bar and an intent floating over a corpse are stale information the player still reads.
    _hide_combat_ui_on_death()

    SFXPlayer.play(DEATH_SOUND, false, randf_range(0.72, 0.8), -2.0)

    # Each dying enemy owns its own tween, so simultaneous deaths in a swarm OVERLAP rather
    # than queueing - measured at 1.39s total for a 3-body wipe, not 3x1.3s. That is why
    # this sequence needs no "fast animations" escape hatch.
    var death_tween := create_tween()
    death_tween.tween_interval(DEATH_PRE_DELAY)
    death_tween.tween_callback(_spawn_death_fragments)
    death_tween.tween_property(self, "modulate:a", DEATH_GHOST_ALPHA, DEATH_GHOST_FADE) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    death_tween.tween_interval(DEATH_HOLD)
    death_tween.tween_property(self, "modulate:a", 0.0, DEATH_FADE_OUT) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    death_tween.tween_callback(queue_free)


func _hide_combat_ui_on_death() -> void:
    for ui: Node in [stats_ui, intent_ui, status_handler, name_label_layer, arrow]:
        if is_instance_valid(ui):
            ui.hide()


# Little tumbling chips that peel off the body and drift upward. Our answer to the
# reference's flakes: they're the shape of a die corner, and they're tinted by the ACTIVE
# die type's accent - so a magma kill throws orange fragments and a blue kill throws
# indigo, the same rule the directional hit smear already follows. The weapon that made
# the kill is visible in the kill.
func _spawn_death_fragments() -> void:
    var particles := CPUParticles2D.new()
    # Named so it can be told apart from the hit-smear's spark particles, which are also
    # CPUParticles2D children of this same enemy.
    particles.name = "DeathFragments"
    particles.texture = _get_fragment_texture()
    particles.position = sprite_2d.position
    particles.z_index = 1
    particles.amount = DEATH_FRAGMENT_COUNT
    particles.one_shot = true
    particles.lifetime = DEATH_FRAGMENT_LIFETIME
    # Low explosiveness = near-continuous emission across the window, so fragments keep
    # peeling off for the whole death rather than puffing out at t=0 and leaving the
    # corpse to fade alone. This is the single most important number here.
    particles.explosiveness = 0.08
    # Wildly different expiry times, so they don't vanish as a group.
    particles.lifetime_randomness = 0.75

    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    var body_height := 96.0
    if sprite_2d.texture:
        body_height = sprite_2d.texture.get_height() * absf(sprite_2d.scale.y)
    # 0.35 of the body height: at 0.25 the chips all came from a tight knot at the centre
    # of mass, so the silhouette's edges never peeled.
    particles.emission_sphere_radius = maxf(body_height * 0.35, 16.0)

    # Up and slightly to the right, with NEGATIVE gravity so they rise the whole way.
    particles.direction = Vector2(0.35, -1.0)
    particles.spread = 30.0
    particles.initial_velocity_min = 55.0
    particles.initial_velocity_max = 110.0
    particles.gravity = Vector2(0.0, -90.0)

    # Every chip tumbles at its own rate from its own starting angle.
    particles.angular_velocity_min = -110.0
    particles.angular_velocity_max = 110.0
    particles.angle_min = -180.0
    particles.angle_max = 180.0

    # Pop in, hold, shrink out (rather than a linear shrink, which reads as "fading").
    # Sizes raised alongside the count for the same mass reason - a 12px chip at 0.5 scale
    # is 6px on screen, below the ~4px floor where an effect stops existing at speed.
    particles.scale_amount_min = 0.9
    particles.scale_amount_max = 1.7
    particles.scale_amount_curve = _get_fragment_scale_curve()

    particles.color = DicePalette.accent(Global.dice_type)

    add_child(particles)
    particles.emitting = true


static func _get_fragment_texture() -> ImageTexture:
    if _fragment_texture:
        return _fragment_texture
    # A tiny chipped square - a die corner. Built in code so there's no asset to keep in
    # sync, same approach as the hit-smear gradient above.
    var size := 12
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in size:
        for x in size:
            # Chamfer the corners so it reads as a chip rather than a pixel.
            var edge_dist: int = mini(mini(x, size - 1 - x), mini(y, size - 1 - y))
            if x + y < 2 or (size - 1 - x) + (size - 1 - y) < 2:
                continue
            # Bright core, slightly softer rim, so it still has a silhouette when tinted.
            var v := 1.0 if edge_dist >= 1 else 0.75
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    _fragment_texture = ImageTexture.create_from_image(img)
    return _fragment_texture


static func _get_fragment_scale_curve() -> Curve:
    if _fragment_scale_curve:
        return _fragment_scale_curve
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.15))
    curve.add_point(Vector2(0.17, 1.0))
    curve.add_point(Vector2(0.43, 1.0))
    curve.add_point(Vector2(1.0, 0.2))
    _fragment_scale_curve = curve
    return _fragment_scale_curve


# Damage-free hit flash + reaction, for thrown dice that carry no damage of their own
# (All In's consumed dice - their total lands once on the final die). Makes each bash
# physically register on the enemy like a real attack-card hit. Guards against a dead/
# dying enemy so it never fights take_damage()'s death branch over the material.
func flash_impact() -> void:
    if stats.health <= 0:
        return
    sprite_2d.material = WHITE_SPRITE_MATERIAL
    _play_hit_reaction()
    var flash_tween := create_tween()
    flash_tween.tween_interval(0.06)
    flash_tween.tween_callback(
        func():
            if is_instance_valid(self) and stats.health > 0:
                sprite_2d.material = _base_sprite_material
    )


# Directional slash smear on hit: a two-layer streak (wide accent sweep + thin white-hot
# core) sweeping upper-left to lower-right (the player attacks from the left), with a
# handful of sparks flung along the slash direction. Tinted by the active dice type's
# accent so a magma hit slashes orange, a blue hit indigo. This REPLACES the old radial
# card-particle burst on attacks (gated off in card.gd::play - the burst buried the
# slash; Julien, 2026-08). Length/sparks scale with damage; hits under
# HIT_SMEAR_MIN_DAMAGE (a true zero) stay smear-free. Spawned as children
# of this enemy so multi-body fight scales (0.65-0.75 Enemy.scale) shrink it with the body.
func _spawn_hit_smear(damage: int) -> void:
    if damage < HIT_SMEAR_MIN_DAMAGE:
        return
    # Variant board dispatch. The three new styles all spawn on the IMPACT FRAME with no
    # deferral - dodging the white flash is exactly what cost the old slash its freeze
    # frame, and each of them handles the flash instead: the crescent is born white-hot
    # and blooms to colour AS the flash decays, and the wound is a dark slit which is at
    # its most visible over a white silhouette.
    match slash_style:
        SlashStyle.CRESCENT:
            _spawn_crescent_slash(damage)
            return
        SlashStyle.WOUND:
            _spawn_wound(damage)
            return
        SlashStyle.FLURRY:
            _spawn_flurry(damage)
            return
    # Deferred a beat past take_damage's white flash: the smear used to spawn in the same
    # instant the whole sprite went flat white, and additive light over a white silhouette
    # is invisible - "I can barely see it" (Julien, 2026-08). Now the beat is flash pop ->
    # colored slash sweeping the restored sprite. The delay tween is owned by this node,
    # so a killing blow that frees the enemy silently cancels the pending slash.
    var delay := create_tween()
    delay.tween_interval(0.055)
    delay.tween_callback(_spawn_hit_smear_now.bind(damage))


func _spawn_hit_smear_now(damage: int) -> void:
    var accent := DicePalette.accent(Global.dice_type)
    var angle := 0.55 + randf_range(-0.12, 0.12)
    var dir := Vector2(cos(angle), sin(angle))
    var length := clampf(88.0 + damage * 6.0, 88.0, 230.0)
    var origin := sprite_2d.position \
            + Vector2(randf_range(-10.0, 10.0), randf_range(-14.0, 6.0)) - dir * length * 0.35
    # Two blend modes on purpose, one per failure mode: the wide sweep is NORMAL-blend
    # saturated accent (additive washes to pastel and dies on light backgrounds - this is
    # what makes the slash read as unmistakably BLUE/ORANGE/etc), the thin core is
    # additive white-hot (which is what survives on dark act-2 backgrounds). Between the
    # two, some layer is loud on every ground the game has.
    _spawn_smear_streak(origin, dir, angle, length,
            Vector2(length / 64.0, 0.78),
            Color(accent.r, accent.g, accent.b, 0.95), 0.72, false)
    _spawn_smear_streak(origin + dir * 12.0, dir, angle, length,
            Vector2(length / 64.0 * 1.12, 0.24),
            Color(1.8, 1.75, 1.6, 0.95), 0.46, true)

    # The MASS: a dense one-shot cone of accent motes blasting along the slash line. This
    # is what the old radial burst had that streaks alone don't - ~75 glowing particles
    # for half a second reads as an event, 2 sprites read as a glint ("the particles were
    # 10x more noticeable", Julien 2026-08). Same particle language the burst spoke, but
    # AIMED: spread 26° instead of 165°, so the explosion continues the cut instead of
    # saying "something happened here".
    var burst := CPUParticles2D.new()
    burst.one_shot = true
    burst.explosiveness = 1.0
    burst.amount = clampi(40 + damage * 3, 40, 90)
    burst.lifetime = 0.42
    burst.texture = _get_smear_texture()
    burst.material = _get_smear_material()
    burst.direction = dir
    burst.spread = 26.0
    burst.initial_velocity_min = 220.0
    burst.initial_velocity_max = 480.0
    burst.gravity = Vector2(0, 260)
    burst.scale_amount_min = 0.07
    burst.scale_amount_max = 0.16
    burst.color = Color(accent.r * 1.6, accent.g * 1.6, accent.b * 1.6, 1.0)
    burst.z_index = 8
    add_child(burst)
    burst.position = origin + dir * length * 0.4
    burst.emitting = true
    var cleanup := burst.create_tween()
    cleanup.tween_interval(0.75)
    cleanup.tween_callback(burst.queue_free)
    # Sparks flung along the slash: the debris that continues the force after the streak
    # fades. Count scales with damage.
    var spark_count := 3 + mini(damage / 5, 4)
    for i in spark_count:
        var spark := Sprite2D.new()
        spark.texture = _get_smear_texture()
        spark.material = _get_smear_material()
        spark.modulate = Color(accent.r + 0.6, accent.g + 0.6, accent.b + 0.6,
                randf_range(0.6, 0.9))
        spark.z_index = 9
        var s := randf_range(0.10, 0.22)
        spark.scale = Vector2(s * randf_range(1.6, 2.6), s)
        var spark_dir := dir.rotated(randf_range(-0.35, 0.35))
        spark.rotation = spark_dir.angle()
        add_child(spark)
        spark.position = origin + dir * length * randf_range(0.35, 0.75)
        var travel := spark_dir * randf_range(55.0, 130.0)
        var spark_tw := spark.create_tween()
        spark_tw.tween_property(spark, "position", spark.position + travel,
                randf_range(0.16, 0.26)) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        spark_tw.parallel().tween_property(spark, "modulate:a", 0.0, randf_range(0.14, 0.24)) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        spark_tw.tween_callback(spark.queue_free)


# One streak layer of the slash. The streak sweeps forward along `dir` while stretching
# slightly and fading - motion sells the cut more than the shape does. `additive` false =
# normal blend, for saturated color that survives light backgrounds and the white flash.
func _spawn_smear_streak(origin: Vector2, dir: Vector2, angle: float, length: float,
        streak_scale: Vector2, color: Color, life: float, additive := true) -> void:
    var smear := Sprite2D.new()
    smear.texture = _get_smear_texture()
    if additive:
        smear.material = _get_smear_material()
    smear.modulate = color
    # ⚠️ The enemy's Sprite2D sits at z_index 7 (enemy.tscn) - anything lower renders
    # BEHIND the body, which is why the first slashes were barely visible. 9 clears the
    # sprite while staying under the IntentUI at 10.
    smear.z_index = 9
    smear.rotation = angle
    smear.scale = streak_scale
    add_child(smear)
    smear.position = origin
    # Anime-slash anatomy: the sweep happens FAST (first ~45% of life), then the line
    # HOLDS at full brightness before fading slowly - "I barely have time to see what's
    # going on" (Julien, 2026-08) was the old everything-in-motion-while-fading version.
    # Two tweens: motion, then a separate hold-then-fade owning alpha and the free.
    var tw := smear.create_tween()
    tw.tween_property(smear, "position", origin + dir * length * 0.6, life * 0.45) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(smear, "scale:x", streak_scale.x * 1.3, life * 0.45) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var fade := smear.create_tween()
    fade.tween_interval(life * 0.35)
    fade.tween_property(smear, "modulate:a", 0.0, life * 0.65) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    fade.tween_callback(smear.queue_free)


# ---------------------------------------------------------------------------
# STYLE: CRESCENT (suggestions 1+2)
# ---------------------------------------------------------------------------

func _spawn_crescent_slash(damage: int) -> void:
    var rung: int = Shaker.impact_for_damage(damage)
    var hold: float = CRESCENT_HOLD[rung]
    var length: float = CRESCENT_LENGTH[rung]
    _spawn_crescent_blade(CRESCENT_ANGLE + randf_range(-0.09, 0.09), length, hold, true, damage)


# One blade. Appears at full length, holds dead still at peak brightness, then dissolves
# tail-first. `with_cone` gates the particle mass so a flurry does not spray three times.
func _spawn_crescent_blade(angle: float, length: float, hold: float, with_cone: bool,
        damage: int) -> void:
    var accent := DicePalette.accent(Global.dice_type)
    var dir := Vector2(cos(angle), sin(angle))
    var origin := sprite_2d.position + Vector2(randf_range(-9.0, 9.0), randf_range(-12.0, 6.0))

    # Same two-blend-mode split the shipped smear established, and for the same two failure
    # modes: the wide layer is NORMAL-blend saturated accent (additive washes to pastel and
    # dies on light act-1 grounds - this is what makes the cut read unmistakably
    # BLUE/ORANGE), the thin core is additive white-hot (which is what survives on dark
    # act-2 grounds). Some layer is always loud on every ground the game has.
    # Both layers take the SAME scale so their arcs are concentric - only the texture
    # differs. Thinning the core via scale.y instead would flatten its bow and the two
    # shapes would visibly disagree.
    var base_scale := length / float(CRESCENT_TEX_W)
    var thick_rung: int = Shaker.impact_for_damage(damage)
    var thickness := base_scale * float(CRESCENT_THICKNESS[thick_rung])
    _spawn_crescent_layer(origin, angle, base_scale, thickness,
            Color(accent.r * 1.4, accent.g * 1.4, accent.b * 1.4, 0.98), hold, false, false)
    # 1.55, not the 2.0 this first shipped with: at 2.0 the additive core blew out the
    # whole blade to white and the dice-type accent - the part Julien explicitly likes -
    # only survived as a thin fringe. The core is meant to be the hot line INSIDE a
    # coloured blade, not the blade.
    _spawn_crescent_layer(origin, angle, base_scale, thickness,
            Color(1.72, 1.68, 1.55, 0.96), hold, true, true)

    if with_cone:
        _spawn_slash_cone(origin, dir, angle, length, accent, damage)


func _spawn_crescent_layer(origin: Vector2, angle: float, scale_x: float, scale_y: float,
        target_color: Color, hold: float, additive: bool, core: bool) -> void:
    var blade := Sprite2D.new()
    blade.texture = _get_crescent_core_texture() if core else _get_crescent_texture()
    var mat := ShaderMaterial.new()
    mat.shader = _get_wipe_shader(additive)
    mat.set_shader_parameter("wipe", 0.0)
    mat.set_shader_parameter("wipe_soft", 0.34)
    blade.material = mat
    # The enemy's Sprite2D sits at z_index 7 (enemy.tscn) - anything lower renders BEHIND
    # the body. 9 clears the sprite while staying under the IntentUI at 10.
    blade.z_index = 9
    blade.rotation = angle
    # Born white-hot so it belongs to the same event as take_damage's white flash instead
    # of hiding from it, then blooms into the dice colour as that flash decays.
    blade.modulate = Color(2.0, 1.95, 1.85, 0.97)
    add_child(blade)
    blade.position = origin
    var full_y := CRESCENT_BOW_SIGN * scale_y
    blade.scale = Vector2(scale_x * 0.34, full_y)

    # The blade's ONLY motion: a front-loaded draw-on short enough to land inside the
    # freeze. QUINT rather than EXPO - EXPO puts ~90% of the travel in the first fifth and
    # reads as a pop (lesson from the reverted charge shockwave).
    var draw := blade.create_tween()
    draw.tween_property(blade, "scale:x", scale_x, CRESCENT_DRAW_ON) \
        .set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

    var bloom := blade.create_tween()
    bloom.tween_interval(CRESCENT_DRAW_ON)
    bloom.tween_property(blade, "modulate", target_color, CRESCENT_BLOOM) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # Dissolve along the blade's own length instead of a uniform alpha fade: a line that
    # un-draws itself keeps reading as a cut right to the end, where a whole-sprite fade
    # turns into a dimming smudge halfway through.
    var wipe := blade.create_tween()
    wipe.tween_interval(CRESCENT_DRAW_ON + CRESCENT_BLOOM + hold)
    wipe.tween_property(mat, "shader_parameter/wipe", 1.3, CRESCENT_DISSOLVE) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    wipe.tween_callback(blade.queue_free)


# The MASS. Streaks alone read as a glint; ~75 glowing motes for half a second read as an
# event ("the particles were 10x more noticeable", Julien 2026-08). Same particle language
# the old radial burst spoke, but AIMED along the cut instead of radial.
func _spawn_slash_cone(origin: Vector2, dir: Vector2, _angle: float, length: float,
        accent: Color, damage: int) -> void:
    var burst := CPUParticles2D.new()
    burst.one_shot = true
    burst.explosiveness = 1.0
    burst.amount = clampi(52 + damage * 4, 52, 130)
    burst.lifetime = 0.46
    burst.texture = _get_smear_texture()
    burst.material = _get_smear_material()
    burst.direction = dir
    burst.spread = 32.0
    burst.initial_velocity_min = 190.0
    burst.initial_velocity_max = 430.0
    burst.gravity = Vector2(0, 190)
    burst.scale_amount_min = 0.07
    burst.scale_amount_max = 0.16
    burst.color = Color(accent.r * 1.6, accent.g * 1.6, accent.b * 1.6, 1.0)
    burst.z_index = 8
    add_child(burst)
    # Erupt from where the blade crosses the BODY, not from the far end of the arc: the
    # first render put the cone ~88px past the target and it read as a separate little
    # puff sitting next to the enemy rather than as debris from the cut.
    burst.position = origin + dir * length * 0.1
    burst.emitting = true
    var cleanup := burst.create_tween()
    cleanup.tween_interval(0.8)
    cleanup.tween_callback(burst.queue_free)


# ---------------------------------------------------------------------------
# STYLE: WOUND (suggestion 3)
# ---------------------------------------------------------------------------

# A mark that OUTLIVES the hit, so how fast it arrived stops mattering. Parented to the
# Sprite2D, which means it inherits the hit squash, the knockback, the enemy's per-fight
# scale and the death fade for free - it behaves like part of the body because it is.
func _spawn_wound(damage: int) -> void:
    var rung: int = Shaker.impact_for_damage(damage)
    var accent := DicePalette.accent(Global.dice_type)
    var angle := CRESCENT_ANGLE + randf_range(-0.12, 0.12)
    # A hit that lands while three marks are already open would read as clutter rather than
    # damage, so the oldest is retired instead of accumulating across a 5-card turn.
    # Rebuilt with an explicit loop, NOT Array.filter(): filter() returns an untyped
    # Array, and assigning that back into an Array[Node] throws at runtime - which aborted
    # this whole function from the second hit onwards, so no wound ever appeared after the
    # first one. gdtoolkit parses it happily; only running it surfaces this.
    var alive: Array[Node] = []
    for w in _wounds:
        if is_instance_valid(w):
            alive.append(w)
    _wounds = alive
    while _wounds.size() >= WOUND_MAX_CONCURRENT:
        var oldest: Node = _wounds.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

    # Local space here is the sprite's own texture pixels, so sizing off the texture rect
    # makes the mark body-relative on every enemy automatically - no per-art tuning, and a
    # 0.65-scale swarm body gets a proportionally smaller cut for free.
    var rect := sprite_2d.get_rect()
    var length := rect.size.x * randf_range(0.5, 0.62)
    var px_to_local := 1.0 / maxf(absf(sprite_2d.scale.x), 0.001)
    var thickness_px: float = WOUND_THICKNESS_PX[rung]
    var scale_y := (thickness_px * px_to_local) / WOUND_BAND_PX
    var scale_x := length / float(WOUND_TEX_W)

    # A group so open/close/heal drive both layers as one object while each layer keeps
    # its own colour ramp (modulate multiplies down the tree, so a shared bloom tween
    # could not take one layer to accent-glow and the other to a dark slit).
    var group := Node2D.new()
    # Relative z (default z_as_relative) so it sits just above the body at effective 8,
    # still under the IntentUI at 10.
    group.z_index = 1
    group.rotation = angle
    group.position = rect.get_center() + Vector2(
            randf_range(-rect.size.x * 0.07, rect.size.x * 0.07),
            randf_range(-rect.size.y * 0.12, rect.size.y * 0.05))
    group.scale = Vector2(0.12, 1.0)
    sprite_2d.add_child(group)
    _wounds.append(group)

    # LAYER 1 - the glow. Load-bearing: the first build was the dark slit alone, and the
    # render showed it essentially vanishing the moment the white flash ended (a thin dark
    # line on a mid-tone cel body is about the least visible mark you can draw). The slit
    # is what makes it read as a CUT; the glow is what makes it read at all.
    var glow := Sprite2D.new()
    glow.texture = _get_crescent_texture()
    glow.material = _get_smear_material()
    glow.modulate = Color(1.7, 1.66, 1.55, 0.85)
    glow.scale = Vector2(length / float(CRESCENT_TEX_W),
            CRESCENT_BOW_SIGN * (thickness_px * 3.5 * px_to_local) / CRESCENT_BAND_PX)
    group.add_child(glow)

    # LAYER 2 - the slit itself: near-black core with a hot rim, i.e. broken cel linework.
    # At its most visible over take_damage's white silhouette, which is exactly when it
    # spawns - this style uses the flash instead of hiding from it.
    var slit := Sprite2D.new()
    slit.texture = _get_wound_texture()
    slit.modulate = Color(2.2, 2.1, 1.95, 1.0)
    slit.scale = Vector2(scale_x, CRESCENT_BOW_SIGN * scale_y)
    group.add_child(slit)

    # The cut OPENS fast, then the two layers take the dice colour, then it just sits there.
    var open := group.create_tween()
    open.tween_property(group, "scale:x", 1.0, WOUND_OPEN) \
        .set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

    # ⚠️ .parallel() on the SECOND tweener, never set_parallel(true) after an interval:
    # set_parallel appends into the CURRENT step, which is the interval's - so the colour
    # ramp (and, below, the whole fade-out) ran simultaneously with its own delay instead
    # of after it. That is what made the first wound build vanish ~6 frames after landing
    # while its hold timer still had 0.7s to run.
    var bloom := group.create_tween()
    bloom.tween_interval(WOUND_OPEN)
    # Deliberately restrained once it settles: the glow is additive, and at the brightness
    # it is BORN with it saturates to white and the dice colour - the part Julien likes -
    # disappears into the bloom. Hot on the impact frame, saturated blue/orange/etc for the
    # rest of its life.
    bloom.tween_property(glow, "modulate", _hot_accent(accent, 0.05, 1.15, 0.6), WOUND_BLOOM) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    bloom.parallel().tween_property(slit, "modulate",
            _hot_accent(accent, 0.35, 1.85, 1.0), WOUND_BLOOM) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # Heals shut rather than fading out: the slit closes on the thickness axis while the
    # glow drains, which reads as a wound sealing instead of a decal being turned off.
    var hold: float = WOUND_HOLD[rung]
    var close := group.create_tween()
    close.tween_interval(WOUND_OPEN + WOUND_BLOOM + hold)
    close.tween_property(group, "scale:y", 0.06, WOUND_CLOSE) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    close.parallel().tween_property(group, "modulate:a", 0.0, WOUND_CLOSE) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    close.chain().tween_callback(group.queue_free)

    # A short spark cone on the impact frame so the hit still has MASS - the mark alone is
    # a quiet artifact, and quiet is what the complaint was about.
    var dir := Vector2(cos(angle), sin(angle))
    _spawn_slash_cone(sprite_2d.position, dir, angle,
            CRESCENT_LENGTH[rung] * 0.7, accent, damage)


# ---------------------------------------------------------------------------
# STYLE: FLURRY (suggestion 4)
# ---------------------------------------------------------------------------

# The damage ladder as CHOREOGRAPHY rather than intensity: today damage only scales the
# streak's length/brightness/particle count, so a 20 looks like a 6 with the contrast
# turned up. Here the PATTERN escalates - one cut, two crossing cuts, a three-slash flurry
# whose last blade is the longest and holds longest, and only that final blade carries the
# particle cone so the event ends on its biggest beat. Same philosophy as the roll ladder.
func _spawn_flurry(damage: int) -> void:
    var rung: int = Shaker.impact_for_damage(damage)
    var count: int = FLURRY_COUNT[rung]
    var base_length: float = CRESCENT_LENGTH[rung]
    var base_hold: float = CRESCENT_HOLD[rung]
    if count <= 1:
        _spawn_crescent_blade(CRESCENT_ANGLE + randf_range(-0.09, 0.09),
                base_length, base_hold, true, damage)
        return
    # Enemy-owned so a killing blow silently cancels the blades still queued behind it.
    var seq := create_tween()
    for i in count:
        var idx := i
        if idx > 0:
            seq.tween_interval(FLURRY_STAGGER)
        var is_last := idx == count - 1
        var angle: float = FLURRY_ANGLES[idx % FLURRY_ANGLES.size()] + randf_range(-0.07, 0.07)
        var mul: float = FLURRY_LENGTH_MUL[idx % FLURRY_LENGTH_MUL.size()]
        # Early blades snap through; only the finisher gets a real hold, so the flurry
        # reads as build-up -> payoff instead of three equal flashes.
        var hold := base_hold * (1.25 if is_last else 0.28)
        seq.tween_callback(_spawn_crescent_blade.bind(
                angle, base_length * mul, hold, is_last, damage))


# Directional knockback + sprite squash on hit. Knockback rides self.position (the same
# property Shaker.shake uses safely), squash rides Sprite2D.scale directly - the idle is
# a shader deformation now, so nothing else fights over these transforms.
func _play_hit_reaction() -> void:
    if not _hit_reaction_active:
        _hit_rest_position = position
        _hit_rest_sprite_scale = sprite_2d.scale
        _hit_reaction_active = true

    if _hit_pos_tween and _hit_pos_tween.is_valid():
        _hit_pos_tween.kill()
    if _hit_squash_tween and _hit_squash_tween.is_valid():
        _hit_squash_tween.kill()

    # Enemies sit to the right of the player, so they recoil rightward (+x).
    _hit_pos_tween = create_tween()
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position + Vector2(16, 0), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_callback(func(): _hit_reaction_active = false)

    _hit_squash_tween = create_tween()
    _hit_squash_tween.tween_property(sprite_2d, "scale", Vector2(_hit_rest_sprite_scale.x * 1.15, _hit_rest_sprite_scale.y * 0.85), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_squash_tween.tween_property(sprite_2d, "scale", _hit_rest_sprite_scale, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_area_entered(_area: Area2D) -> void:
    arrow.hide()


func _on_area_exited(_area: Area2D) -> void:
    arrow.hide()


func _on_mouse_entered() -> void:
    name_label.text = _display_name
    # Center the label on the visible red HealthBar's actual on-screen center - that bar
    # is the anchor the player reads "centered" against, and it sidesteps per-art
    # content-centering guesswork entirely (a swapped act-2 sprite lines up as well as a
    # hand-tuned act-1 one). NOTE: StatsUI is an HBoxContainer, so its own rect center is
    # NOT the bar center (the bar is one child among Block/Health/Margin) - we must read
    # the HealthBar node itself. The label lives in a CanvasLayer (screen space), so the
    # bar's canvas-space center is pushed through the viewport's canvas transform first;
    # the old code used raw canvas coords as screen offsets AND the sprite center rather
    # than the bar, which drifted the name off-center. Recomputed each hover so it stays
    # correct even if the enemy shifted (e.g. mid hit-reaction knockback).
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    var bar_center_x: float = health_bar.get_global_rect().get_center().x if health_bar \
        else stats_ui.get_global_rect().get_center().x
    var world_y := global_position.y + _name_label_local_y * scale.y
    var screen: Vector2 = get_viewport().get_canvas_transform() * Vector2(bar_center_x, world_y)
    name_label_layer.offset = Vector2(screen.x - NAME_LABEL_WIDTH / 2.0, screen.y)
    name_label.show()


func _on_mouse_exited() -> void:
    name_label.hide()


# EnemyStats.enemy_name wins if set; otherwise derive a readable name from the .tres filename
# (e.g. "goblin_enemy.tres" -> "Goblin", "temple_defender_enemy.tres" -> "Temple Defender" -
# String.capitalize() already turns snake_case into Title Case). Only wrong for the one enemy
# whose file name doesn't match its design name (crab.tres is the design's "Skeleton") - set
# enemy_name explicitly on that one .tres rather than trying to special-case it here.
func _compute_display_name(source_stats: EnemyStats) -> String:
    if source_stats.enemy_name != "":
        return source_stats.enemy_name
    if source_stats.resource_path == "":
        return "Enemy"
    var file_name := source_stats.resource_path.get_file().get_basename()
    return file_name.trim_suffix("_enemy").capitalize()


func set_target_highlight(active: bool) -> void:
    if not _base_sprite_material:
        return
    if _target_highlight_tween and _target_highlight_tween.is_valid():
        _target_highlight_tween.kill()
    # take_damage()'s hit-flash temporarily swaps sprite_2d.material to
    # WHITE_SPRITE_MATERIAL; make sure our own outline shader is the one
    # actually assigned before driving its parameters.
    sprite_2d.material = _base_sprite_material
    if active:
        _base_sprite_material.set_shader_parameter("outline_color", TARGET_HIGHLIGHT_OUTLINE_COLOR)
        _target_highlight_tween = create_tween()
        _target_highlight_tween.tween_property(_base_sprite_material, "shader_parameter/outline_thickness", TARGET_HIGHLIGHT_OUTLINE_THICKNESS, TARGET_HIGHLIGHT_FADE_IN_DURATION)
    else:
        # Instant, unconditional snap to zero — no tween to interrupt or leave
        # at a partial value if this gets called again before a fade finishes.
        # Alpha is zeroed too as a second guarantee of invisibility regardless
        # of thickness, in case anything else nudges thickness back up later.
        _base_sprite_material.set_shader_parameter("outline_thickness", 0.0)
        var faded_color := TARGET_HIGHLIGHT_OUTLINE_COLOR
        faded_color.a = 0.0
        _base_sprite_material.set_shader_parameter("outline_color", faded_color)
   
