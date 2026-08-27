class_name Player
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
# Outline+sway shader shared with enemies (outline disabled here) - the feet-planted
# idle deformation that replaced the AnimationPlayer transform bob (2026-07-23).
const SWAY_SHADER := preload("res://scenes/enemy/enemy.gdshader")

# --- Shipped hero art / sprite transform ------------------------------------------------
# main_character_chibi.png now holds the 2026-08-25 hero (debug candidate character_01, the
# one Julien picked off the in-game A/B). The FILE NAME is legacy - the art is not a chibi -
# but overwriting in place keeps warrior.tres and this scene's ext_resource (and its uid)
# untouched, and makes the next swap a single file copy.
#
# Sprite2D's scale/position in player.tscn are NOT authored by eye: they are the same
# normalisation apply_debug_texture() applies below, baked in, so the new art keeps the OLD
# art's on-screen body height (249.6px), feet line (y=123.6, which is exactly where StatsUI
# is pinned) and body centre. Swapping the art again means recomputing them from the two
# alpha bboxes - do not just drop a new PNG in and leave 0.709091 behind.

# --- Held die (2026-08-27) ---------------------------------------------------------------
# The hero levitates a die above his open palm. It is its own Sprite2D - split out of the
# body art by split_hero_die.py, which leaves both halves on the SAME canvas so the die
# drops back into the hole it left - because it has to do two things a baked-in die can't:
#
#   * recolour to the ACTIVE dice type, so the resource you are rolling is visibly the one
#     the character holds. Everything that says "you are on Magma" used to live in the dice
#     cluster while the hero sat inert on the far side of the frame; this ties the two
#     halves of the screen together, and it is infusion-aware for free via DicePalette.
#   * punch forward when you play an attack, giving the slash that lands a beat later a
#     visible cause. The hero was the only actor on screen that never moved when it acted
#     (enemies lunge, thrown dice fly, the big die hops).
#
# Because it MOVES it cannot simply be drawn over the baked one - the original would peek
# out from under it - hence a genuine split rather than an occluding overlay.
const DIE_TEXTURE_PATH := "res://main_character_die.png"
# Accent lifted toward white. At its real ~38px on-screen size a fully saturated cobalt or
# fuchsia die goes muddy against the navy cloak; 0.15 keeps the identity and the luminance.
const DIE_TINT_WHITE_LIFT := 0.15
# Enemies stand to the RIGHT of the hero, so the thrust travels right-and-up. ~15px on a
# 38px die is ~40% of its own width - comfortably over the ~4px floor below which an effect
# does not exist at play speed.
const DIE_PUNCH_OFFSET := Vector2(15.0, -11.0)
const DIE_PUNCH_SCALE := 1.16
const DIE_PUNCH_ROTATION := 0.22  # radians; a flick, not a tumble
const DIE_PUNCH_OUT := 0.07
const DIE_PUNCH_BACK := 0.34
# A switch of dice type re-attunes the die: brief flash toward white, then settle into the
# new accent, with a fractional punch so the change is felt and not just seen.
const DIE_RETUNE_PUNCH := 0.45

@export var stats: CharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@onready var stats_ui: StatsUI = $StatsUI
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Hit-reaction state (knockback + squash), mirrors Enemy.take_damage.
var _hit_pos_tween: Tween
var _hit_squash_tween: Tween
var _hit_rest_position: Vector2
var _hit_rest_sprite_scale: Vector2
var _hit_reaction_active := false
var _sway_material: ShaderMaterial
var _ground_shadow: Sprite2D
# Held die: a pivot parked on the die's INK centre (so a punch scales/rotates about the die
# and not about the empty canvas centre it would otherwise orbit), and the sprite itself.
var _die_pivot: Node2D
var _die_sprite: Sprite2D
var _die_rest_position: Vector2
var _die_punch_tween: Tween
var _die_tint_tween: Tween
var _debug_hero_override_active := false
# The scene's authored sprite transform, captured before the debug hero swap can touch it so
# clearing the swap can restore it exactly. ZERO = not captured yet.
var _base_sprite_scale := Vector2.ZERO
var _base_sprite_pos := Vector2.ZERO


func _ready() -> void:
    Global.player = self  # now your card knows who the player is
    status_handler.status_owner = self
    Events.event_damage.connect(_on_event_damage)
    #var infused := preload("res://statuses//infused.tres")
    #infused.duration = 1
    #status_handler.add_status(infused)

    # Feet-planted idle sway (replaces the AnimationPlayer transform bob, which no
    # longer autoplays): boots stay welded to the ground, shoulders/cape lean with the
    # hood trailing a beat, chest rises on the inhale. Hero preset tuned in SCREEN px
    # via the idle_sway_preview A/B (approved by Julien 2026-07-23); the shader wants
    # texture px, hence the divide by the sprite's baked scale. Random phase/speed so
    # the cycle differs per battle.
    _sway_material = ShaderMaterial.new()
    _sway_material.shader = SWAY_SHADER
    _sway_material.set_shader_parameter("outline_thickness", 0.0)
    _sway_material.set_shader_parameter("anti_aliasing", 0.0)
    _sway_material.set_shader_parameter("head_lag", 0.9)
    _apply_sway_scale()  # the four px amplitudes, divided by the sprite scale (see below)
    _sway_material.set_shader_parameter("sway_hz", 0.19)
    _sway_material.set_shader_parameter("breathe_hz", 0.38)
    _sway_material.set_shader_parameter("sway_phase", randf() * 60.0)
    _sway_material.set_shader_parameter("sway_speed", randf_range(0.9, 1.15))
    sprite_2d.material = _sway_material

    # Hang the status row off the VISIBLE red HP bar's bottom-left corner, exactly like
    # enemies do (enemy.gd::_update_status_row_placement) - one rule for the whole game, so
    # the hero's row can't drift away from the enemies' convention. StatsUI is a centring
    # HBoxContainer whose own left edge sits ~20px LEFT of the bar the player actually sees,
    # so the row's hand-tuned .tscn offset could never line up on either axis.
    status_handler.sort_children.connect(_update_status_row_placement)
    stats_ui.sort_children.connect(_update_status_row_placement)
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    if health_bar != null:
        health_bar.item_rect_changed.connect(_update_status_row_placement)
    _update_status_row_placement()
    _update_ground_shadow()
    _ensure_held_die()
    # active_dice_changed carries the new type, so the handler MUST take an argument - a
    # 0-arg callable connects without complaint here and then silently never runs.
    Events.active_dice_changed.connect(_on_active_dice_changed)
    Events.card_played.connect(_on_card_played)


# See enemy.gd::_update_status_row_placement for the full reasoning; this is the same
# contract on the hero, so the two can't drift apart.
func _update_status_row_placement() -> void:
    if status_handler == null or stats_ui == null:
        return
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    if health_bar == null or health_bar.size.x <= 0.0:
        return
    var xf := health_bar.get_global_transform()
    var c0 := xf * Vector2.ZERO
    var c1 := xf * health_bar.size
    var anchor := Vector2(minf(c0.x, c1.x), maxf(c0.y, c1.y) + Enemy.STATUS_ROW_GAP)
    status_handler.position = to_local(anchor)


# Ground shadow, mirroring Enemy's (enemy.gd::update_enemy). Every enemy builds one and the
# player never did. With the old chibi - a dark, wide, bottom-heavy silhouette - the omission
# was invisible; the 2026-08 hero art has a narrower stance and pale legs, so he read as
# hovering next to enemies that are visibly planted.
#
# Child of the ROOT and moved to index 0 so it draws under SpriteRoot. Note the deliberate
# difference from Enemy: the player's knockback tweens the root (_play_hit_reaction), so the
# shadow travels with the recoil - correct, since the body is genuinely shoved backwards. The
# squash tweens sprite_2d.scale and the idle is a shader deformation, so neither drags it.
# Texture and content-rect come from Enemy's cached statics, so both stay in sync by
# construction if those are ever retuned.
func _update_ground_shadow() -> void:
    if sprite_2d == null or sprite_2d.texture == null:
        return
    if _ground_shadow == null:
        _ground_shadow = Sprite2D.new()
        _ground_shadow.texture = Enemy._get_shadow_texture()
        add_child(_ground_shadow)
        move_child(_ground_shadow, 0)
    var tex_size: Vector2 = sprite_2d.texture.get_size()
    var content: Rect2 = Enemy._get_content_rect(sprite_2d.texture)
    # Feet are the bottom-centre of the INK, not of the canvas - the art is padded.
    var feet := Vector2(
            content.get_center().x - tex_size.x / 2.0,
            content.end.y - tex_size.y / 2.0)
    _ground_shadow.position = to_local(sprite_2d.to_global(feet)) + Vector2(0.0, 5.0)
    var shadow_width: float = content.size.x * sprite_2d.scale.x * 0.82
    _ground_shadow.scale = Vector2(shadow_width / 256.0, shadow_width * 0.24 / 256.0)



# --- Held die ----------------------------------------------------------------------------
# Built in code rather than authored in player.tscn, following the ground shadow above: the
# whole feature is then one script plus one PNG, with no ext_resource/uid/load_steps surface
# in the scene, and pulling it back out is deleting a block.
func _ensure_held_die() -> void:
    if _die_sprite != null or sprite_2d == null:
        return
    var tex := load(DIE_TEXTURE_PATH) as Texture2D
    if tex == null:
        # Hero art was swapped without re-running split_hero_die.py. Degrade to exactly the
        # old behaviour (no overlay) instead of drawing a die that belongs to other art.
        return

    _die_pivot = Node2D.new()
    _die_pivot.name = "HeldDiePivot"
    _die_sprite = Sprite2D.new()
    _die_sprite.name = "HeldDie"
    _die_sprite.texture = tex
    # Deliberately NO material. The shared sway shader ends on `COLOR = tex_color`, a raw
    # texture sample, which overwrites the incoming COLOR and therefore DISCARDS modulate -
    # a sprite wearing it cannot be tinted at all. Editing that shader would touch every
    # enemy in the game for one hero prop, so the die simply opts out of it. The cost is
    # that it does not sway with the body, which is arguably the better read anyway: this
    # die is levitated, not gripped, and the hand it hovers over only travels ~2.5px on
    # screen - under the floor where the difference registers.
    _die_pivot.add_child(_die_sprite)
    sprite_2d.get_parent().add_child(_die_pivot)
    _sync_held_die_transform()
    _update_die_tint()


# Keeps the die welded to the body through every transform the body can take (the authored
# scale, and the debug A/B swap's renormalisation). Derived from the die art's own alpha
# bbox, so re-splitting new art needs no hand-tuned numbers here.
func _sync_held_die_transform() -> void:
    if _die_sprite == null or _die_sprite.texture == null or sprite_2d == null:
        return
    var tex_size: Vector2 = _die_sprite.texture.get_size()
    var content: Rect2 = Enemy._get_content_rect(_die_sprite.texture)
    # Sprite2D centres on its texture, and the die's ink sits far off that centre (~127px
    # right, ~122px up). Parking the pivot on the ink centre is what keeps a scale/rotation
    # punch on the die instead of flinging it across the screen in an arc about the canvas.
    var delta: Vector2 = (content.get_center() - tex_size * 0.5) * sprite_2d.scale
    _die_rest_position = sprite_2d.position + delta
    _die_pivot.position = _die_rest_position
    _die_pivot.scale = Vector2.ONE
    _die_pivot.rotation = 0.0
    _die_sprite.position = -delta
    _die_sprite.scale = sprite_2d.scale


# type_override exists because of a real race: Global.dice_type is assigned inside dice.gd's
# OWN listener of active_dice_changed (dice.gd::_on_active_dice_changed), so whether this node
# sees the new type or the previous one is decided purely by signal connection order. It lost
# that race, and the die rendered exactly one switch behind - Julien had to click a slot twice.
# The signal already carries the new type, so the fix is to trust the argument and never read
# the global on that path. Any future listener that needs the active type at switch time has
# the same trap waiting for it.
func _update_die_tint(animate: bool = false, type_override: String = "") -> void:
    if _die_sprite == null:
        return
    var type: String = type_override if type_override != "" else Global.dice_type
    # accent() is infusion-aware at the single source, so an infused die recolours the one
    # the hero holds for free. An unknown/empty type returns white, which lands back on the
    # die's original painted white - the correct look outside combat.
    var target: Color = DicePalette.accent(type).lerp(Color.WHITE, DIE_TINT_WHITE_LIFT)
    if _die_tint_tween and _die_tint_tween.is_valid():
        _die_tint_tween.kill()
    if not animate:
        _die_sprite.modulate = target
        return
    _die_tint_tween = create_tween()
    _die_tint_tween.tween_property(_die_sprite, "modulate", target.lerp(Color.WHITE, 0.55), 0.09) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _die_tint_tween.tween_property(_die_sprite, "modulate", target, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Thrust toward the enemies. Legs are grouped with .parallel() on the follow-up tweeners
# rather than set_parallel(true), which after a first step would fold the return INTO the
# outward step and play both at once.
func punch_held_die(strength: float = 1.0) -> void:
    if _die_pivot == null:
        return
    if _die_punch_tween and _die_punch_tween.is_valid():
        _die_punch_tween.kill()
        # A punch interrupted mid-flight leaves the pivot away from rest; snap the canonical
        # rest transform back before measuring the new one.
        _die_pivot.position = _die_rest_position

    var out_pos: Vector2 = _die_rest_position + DIE_PUNCH_OFFSET * strength
    var out_scale: Vector2 = Vector2.ONE * (1.0 + (DIE_PUNCH_SCALE - 1.0) * strength)
    var out_rot: float = DIE_PUNCH_ROTATION * strength

    _die_punch_tween = create_tween()
    _die_punch_tween.tween_property(_die_pivot, "position", out_pos, DIE_PUNCH_OUT) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _die_punch_tween.parallel().tween_property(_die_pivot, "scale", out_scale, DIE_PUNCH_OUT) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _die_punch_tween.parallel().tween_property(_die_pivot, "rotation", out_rot, DIE_PUNCH_OUT) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _die_punch_tween.tween_property(_die_pivot, "position", _die_rest_position, DIE_PUNCH_BACK) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _die_punch_tween.parallel().tween_property(_die_pivot, "scale", Vector2.ONE, DIE_PUNCH_BACK) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _die_punch_tween.parallel().tween_property(_die_pivot, "rotation", 0.0, DIE_PUNCH_BACK) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_active_dice_changed(active_dice) -> void:
    _update_die_tint(true, String(active_dice))
    punch_held_die(DIE_RETUNE_PUNCH)


func _on_card_played(card: Card) -> void:
    # Attacks only, matching the gate that spawns the directional slash on the enemy
    # (card.gd) - so the thrust and the cut that lands ~0.055s later read as one beat, and a
    # block or a blessing does not get a phantom attack tell.
    if card != null and card.type == Card.Type.ATTACK:
        punch_held_die()


# Sway amplitudes are authored in SCREEN px (tuned via the idle_sway_preview A/B), so they have
# to be re-divided by the sprite scale whenever that scale changes - which the debug hero swap
# below does. Extracted from _ready() so both callers stay in step.
func _apply_sway_scale() -> void:
    if _sway_material == null or sprite_2d == null or sprite_2d.scale.x == 0.0:
        return
    var to_tex := 1.0 / sprite_2d.scale.x
    _sway_material.set_shader_parameter("sway_px", 4.0 * to_tex)
    _sway_material.set_shader_parameter("head_px", 2.0 * to_tex)
    _sway_material.set_shader_parameter("breathe_px", 3.0 * to_tex)
    _sway_material.set_shader_parameter("margin_px", 6.0 * to_tex)


# --- Debug-only hero swap (global/debug_overlay.gd) ----------------------------------------
# Applies Global.debug_player_texture over the shipped art, or restores the shipped art when it
# is cleared. In a release build that value is always null, so everything past the first branch
# is dead weight there.
#
# The candidates are authored on their own canvases, so a raw texture swap would change both
# how big the hero is and where his feet sit. Instead the
# override is normalised against the shipped art: same on-screen BODY height (the alpha bbox,
# not the canvas - the art is padded), same feet line, same body centre. That makes the swap a
# fair A/B against the enemies and the HP bar rather than a resize.
func apply_debug_texture() -> void:
    if sprite_2d == null or not (stats is CharacterStats):
        return
    # Captured on this node's first call, which update_player() makes while the scene's own
    # authored scale/position are still in place.
    if _base_sprite_scale == Vector2.ZERO:
        _base_sprite_scale = sprite_2d.scale
        _base_sprite_pos = sprite_2d.position

    var base_tex: Texture2D = stats.art
    var override_tex: Texture2D = Global.debug_player_texture
    var base_body := Enemy._get_content_rect(base_tex) if base_tex != null else Rect2()
    var body := Enemy._get_content_rect(override_tex) if override_tex != null else Rect2()
    if override_tex == null or override_tex == base_tex or base_body.size.y <= 0.0 \
            or body.size.y <= 0.0:
        sprite_2d.texture = base_tex
        sprite_2d.scale = _base_sprite_scale
        sprite_2d.position = _base_sprite_pos
    else:
        var base_size := base_tex.get_size()
        var override_size := override_tex.get_size()
        var s := base_body.size.y * _base_sprite_scale.y / body.size.y
        # Sprite2D is centred on its texture, so both anchors are measured from that centre.
        var feet_y := (base_body.end.y - base_size.y * 0.5) * _base_sprite_scale.y \
                + _base_sprite_pos.y
        var centre_x := (base_body.get_center().x - base_size.x * 0.5) * _base_sprite_scale.x \
                + _base_sprite_pos.x
        sprite_2d.texture = override_tex
        sprite_2d.scale = Vector2(s, s)
        sprite_2d.position = Vector2(
                centre_x - (body.get_center().x - override_size.x * 0.5) * s,
                feet_y - (body.end.y - override_size.y * 0.5) * s)

    # Neither can be skipped after a swap: the sway divides by the live sprite scale, and the
    # shadow derives its width and position from the live texture.
    _apply_sway_scale()
    _update_ground_shadow()
    # The A/B candidates are whole characters carrying their own baked die, so the split-out
    # overlay has to step aside for them or the hero holds two. Shipped art keeps it.
    _debug_hero_override_active = sprite_2d.texture != stats.art
    _sync_held_die_transform()
    if _die_pivot != null:
        _die_pivot.visible = not _debug_hero_override_active


func set_character_stats(value: CharacterStats) -> void:
    stats = value
    
    if not stats.stats_changed.is_connected(update_stats):
        stats.stats_changed.connect(update_stats)

    update_player()


func update_player() -> void:
    if not stats is CharacterStats: 
        return
    if not is_inside_tree(): 
        await ready

    sprite_2d.texture = stats.art
    # The debug hero swap rides on top of the shipped art (a no-op when unset) and refreshes
    # the ground shadow itself, so this stays the one place the sprite texture is assigned.
    apply_debug_texture()
    # A battle can open on a type that never emits active_dice_changed (the run's default
    # active die is simply assigned), so the tint is seeded here rather than waiting for a
    # switch that may not come until the second turn.
    _update_die_tint()
    update_stats()


func update_stats() -> void:
    stats_ui.update_stats(stats)


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
    if stats.health <= 0:
        return

    sprite_2d.material = WHITE_SPRITE_MATERIAL
    # The die flashes with the body - it is part of the silhouette, and a tinted die sitting
    # calmly inside a white-hot hero reads as a rendering fault.
    if _die_sprite != null:
        _die_sprite.material = WHITE_SPRITE_MATERIAL
    var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
    # Display (and stats) report what reaches HP, not the raw attack: block soaks first.
    # Mirrors the exact clamp stats.take_damage applies right below.
    Global.blocked_to_display = mini(stats.block, modified_damage)
    Global.damage_to_display = modified_damage - Global.blocked_to_display

    _play_hit_reaction()
    stats.take_damage(modified_damage)
    Events.hp_changed.emit()

    # Short, sharp white flash (was 0.17s). Restore the sway material, NOT null -
    # null would permanently freeze the idle deformation after the first hit taken.
    var flash_tween := create_tween()
    flash_tween.tween_interval(0.06)
    flash_tween.tween_callback(
        func():
            sprite_2d.material = _sway_material
            # Back to null, not _sway_material: the die opts out of the sway shader on
            # purpose (see _ensure_held_die) - handing it that material would silently kill
            # its tint, since the shader discards modulate.
            if _die_sprite != null:
                _die_sprite.material = null
            if stats.health <= 0:
                Events.player_died.emit()
                queue_free()
    )


# Knockback + squash on hit. self.position and Sprite2D.scale are both free of the idle
# (a shader-side deformation since 2026-07-23 - nothing animates SpriteRoot anymore),
# so neither tween fights it.
func _play_hit_reaction() -> void:
    if not _hit_reaction_active:
        _hit_rest_position = position
        _hit_rest_sprite_scale = sprite_2d.scale
        _hit_reaction_active = true

    if _hit_pos_tween and _hit_pos_tween.is_valid():
        _hit_pos_tween.kill()
    if _hit_squash_tween and _hit_squash_tween.is_valid():
        _hit_squash_tween.kill()

    # Player sits to the left of the enemies, so recoils leftward (-x).
    _hit_pos_tween = create_tween()
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position + Vector2(-16, 0), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_callback(func(): _hit_reaction_active = false)

    _hit_squash_tween = create_tween()
    _hit_squash_tween.tween_property(sprite_2d, "scale", Vector2(_hit_rest_sprite_scale.x * 1.15, _hit_rest_sprite_scale.y * 0.85), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_squash_tween.tween_property(sprite_2d, "scale", _hit_rest_sprite_scale, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_event_damage(amount):
    print("taking damage from event")
