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
const HIT_SMEAR_MIN_DAMAGE := 3
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

@export var stats: EnemyStats : set = set_enemy_stats
@export var width: int 
@export var height: int
@export var initial_statuses: Array[Status] = []
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

    # Re-run the status row placement every time it re-lays out: the End Turn clamp needs
    # the row's width, which changes as statuses are gained and lost. Setting position
    # doesn't re-trigger a sort, so this can't loop.
    status_handler.sort_children.connect(_update_status_row_placement)
    # StatsUI is a Container too: its HealthBar only reaches its final x once the container
    # has sorted, and the status row is aligned to that bar.
    stats_ui.sort_children.connect(_update_status_row_placement)

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

    current_action = enemy_action_picker.get_action()


const MAX_ENEMY_WIDTH := 256.0
const MAX_ENEMY_HEIGHT := 256.0

# Keep the status-icon row clear of the End Turn button (BattleUI, bottom-right:
# x 1022..1216, y 554..616 in the 1280x720 design space). The row hangs below the HP bar
# and grows rightward, so on right-side enemies it lands on the button's top-left corner -
# and the button is on a CanvasLayer, so it DRAWS OVER the icons: the stack number, which
# sits in the icon's bottom half, disappears entirely.
# ⚠️ WHY THIS IS NOT A SIDEWAYS CLAMP ANY MORE (2026-08-24). It used to snap the row to
# END_TURN_LEFT - width - gap, an ABSOLUTE x that ignored where the row started. The comment
# here claimed it "pulls left by JUST enough", but the code did the flat yank it said had
# been removed: every affected enemy's row landed on the SAME x (972 for a one-icon row),
# 36-180px from its own bar. Measured on the shipped pool: 22 enemies across 19 fights, and
# in tier_1_crab_satyr / tier_2_defender_satyr BOTH Satyrs' rows stacked on the identical
# pixel, so you could not tell whose Strength was whose. The reported case was the Venom
# Bloom in tier_2_plant_crab: bar at x 1062, its Strength badge parked at 972 on bare floor.
# There is no honest sideways answer for those enemies - their bar's LEFT edge is already
# inside the button's x-band, so NO x under the bar clears it. The dodge is therefore
# VERTICAL: the row flips ABOVE its own bar, the only free space that still reads as
# belonging to this enemy.
# ⚠️ END_TURN_RECT MUST match EndTurnButton's rect in battle.tscn. It was 1060/592 and
# silently went stale on 2026-08-15 when the button was made taller and inset further from
# the corner (offsets -258/-166/-64/-104 -> x 1022..1216, y 554..616): the button moved 38px
# LEFT and 38px UP, so the old numbers left a 38px band on each axis where a status row could
# overlap it with the dodge believing everything was fine. Nothing errors when this drifts -
# the dodge just stops dodging. Re-check it whenever that button moves. Screen-space because
# the battle camera is identity on the 1280x720 design rect and enemy.gd has no clean handle
# into the BattleUI CanvasLayer.
const END_TURN_RECT := Rect2(1022.0, 554.0, 194.0, 62.0)
# The authored StatusUI cell: a 30x30 Icon with the stack/duration label INSIDE it (that
# label's own rect is y 15..30 of the same box - measured, not assumed). Only a floor, for
# the case where the GridContainer's size is read mid-sort before it has laid out.
const STATUS_ICON_EXTENT := 30.0
const STATUS_ROW_ABOVE_GAP := 2.0
# An above-bar row has to clear the body to be seen: Sprite2D is z 7, IntentUI is z 10.
const STATUS_ROW_ABOVE_Z := 8

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


# Local x of the HP bar's LEFT EDGE; the status row starts there. Set by update_enemy().
var _status_row_left_x: float = 17.0
# Local y of the row's normal spot, just under the HP bar (enemy.tscn's authored 145 until
# update_enemy() runs). Kept as a field so the End Turn dodge below can flip the row above
# the bar and hand it back as statuses come and go, without recomputing the normal spot.
var _status_row_below_y: float = 145.0


# Status row starts at the HP bar's LEFT EDGE and grows rightward - the convention in every
# comparable roguelike (Slay the Spire). Do NOT centre it: that was tried once and rejected.
# Re-run whenever the row or the bar re-lays out, because the End Turn dodge depends on the
# row's size, which changes as statuses are gained and lost.
func _update_status_row_placement() -> void:
    if status_handler == null or scale.x == 0.0 or scale.y == 0.0:
        return

    # Align to the VISIBLE red bar, not to StatsUI. StatsUI is a 206px HBoxContainer that
    # centres a 175px HealthBar (plus a Block icon at -25 separation) inside itself, so its
    # left edge sits ~11px LEFT of the bar the player actually sees - which is exactly the
    # "status starts too far left" everyone kept seeing. HealthBar's global position already
    # accounts for the bar's scale, so to_local() gives the right enemy-space x directly.
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    var has_bar: bool = health_bar != null and health_bar.size.x > 0.0
    # Always restart from the untouched spot, so a dodge taken while the row was wide is given
    # back once it shrinks: this function is the only thing that ever moves the row.
    status_handler.position.x = to_local(health_bar.global_position).x if has_bar else _status_row_left_x
    status_handler.position.y = _status_row_below_y
    status_handler.z_index = 0
    if not has_bar:
        return

    var bar_rect: Rect2 = health_bar.get_global_transform() * Rect2(Vector2.ZERO, health_bar.size)
    var row_size: Vector2 = status_handler.size * status_handler.scale
    row_size.x = maxf(row_size.x, STATUS_ICON_EXTENT * STATUS_UI_SCALE)
    row_size.y = maxf(row_size.y, STATUS_ICON_EXTENT * STATUS_UI_SCALE)
    var row := Rect2(status_handler.global_position, row_size)
    if not row.intersects(END_TURN_RECT):
        return

    # Dodge UPWARD, never sideways. Sideways cannot work: for every enemy that hits the
    # button, the bar's own LEFT edge is already inside the button's x-band, so no x under
    # the bar clears it - which is why the old sideways clamp had to detach the row to do
    # anything at all. A bounded "slide left only while the row stays under its own bar" was
    # tried too, and it walks the row into the LEFT NEIGHBOUR's row (tier_0_satyrs_3 at three
    # statuses), swapping one ownership bug for another. Above the bar there is no such
    # competition: the row keeps its x, so two enemies' rows stay exactly as far apart as
    # their bars. It also clears the Block badge, which straddles the bar's left edge and
    # collides with anything parked on the bar itself (that was the other rejected attempt).
    var above_top: float = bar_rect.position.y - row_size.y - STATUS_ROW_ABOVE_GAP
    status_handler.position.y += (above_top - row.position.y) / scale.y
    status_handler.z_index = STATUS_ROW_ABOVE_Z


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
        _status_row_below_y = stats_ui.position.y + stats_ui_drawn_height - 8.0 + maxf(status_handler_y_offset, 0.0)
        # Status row starts at the bar's LEFT EDGE (STS convention - never centred).
        # The bar shrinks about its own centre, so its left edge moves with bar_scale.
        _status_row_left_x = stats_ui.position.x + (stats_ui_width / 2.0) * (1.0 - bar_scale)
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
# HIT_SMEAR_MIN_DAMAGE (block chip, 1-point ticks) stay smear-free. Spawned as children
# of this enemy so multi-body fight scales (0.65-0.75 Enemy.scale) shrink it with the body.
func _spawn_hit_smear(damage: int) -> void:
    if damage < HIT_SMEAR_MIN_DAMAGE:
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
   
