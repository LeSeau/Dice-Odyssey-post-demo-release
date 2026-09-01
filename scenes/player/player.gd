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
# One baked texture per dice type (and per infusion id), built by build_hero_dice.py.
# Swapping the texture rather than tinting with modulate is what lets the pips stay cream
# on a coloured body - a multiply tint can only ever make them a lighter shade of the body.
const DIE_TEXTURE_DIR := "res://hero_die_%s.png"
# Accent lifted toward white. At its real ~38px on-screen size a fully saturated cobalt or
# fuchsia die goes muddy against the navy cloak; 0.15 keeps the identity and the luminance.
# Kept as the value build_hero_dice.py bakes the accents at, so the two stay in step.
const DIE_TINT_WHITE_LIFT := 0.15
# Hot frame the die passes through when it retunes to a new type.
const DIE_RETUNE_FLASH := Color(1.75, 1.75, 1.75)
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

# --- Attack animation pass (2026-08-28) ---------------------------------------------------
# Three channels write the hero's transform and they are deliberately kept on THREE separate
# nodes, because every one of them can be in flight at the same time (you can be hit during
# your own attack):
#
#   root position      <- body lunge AND hit knockback (one shared tween slot, see below)
#   HeldDieBob.y       <- idle levitation bob only
#   HeldDiePivot       <- punch / strike only
#
# Sharing a slot between lunge and knockback is the point: they are the same property, so a
# single tween var plus one canonical rest position makes "two owners fighting" structurally
# impossible rather than merely unlikely.

# Body lunge. The hero stands at x~207 and the enemies at x~750-1150, so the thrust is
# right-and-slightly-up. 14px clears the ~4px floor below which an effect does not exist at
# play speed, without shoving him far enough to break the ground line he shares with them.
const LUNGE_OFFSET := Vector2(14.0, -4.0)
const LUNGE_OUT := 0.07
const LUNGE_BACK := 0.30

# Punch strength per Shaker.Impact rung, indexed by the enum's int value
# (VERY_WEAK, WEAK, MEDIUM, STRONG, HUGE). A plain literal Array rather than a Dictionary
# keyed by Shaker.Impact.*: an autoload is not available at parse time, so keying by the
# enum would be a const that cannot be folded.
# NOTE any read MUST be typed (`var s: float = ...`) - indexing a const Array yields Variant,
# and `:=` on a Variant is the parse error that silently kills an entire file.
const DIE_PUNCH_TIER_STRENGTH := [1.0, 1.0, 1.15, 1.4, 1.7]

# Anticipation: a short pull-back opposite the thrust before the push. This is the whole
# difference between a punch that reads as THROWN and one that reads as a twitch, and it
# costs ~45ms of latency on the game's most common verb.
const DIE_ANTICIPATION_FRAC := -0.35
const DIE_ANTICIPATION_SCALE := 0.96
const DIE_ANTICIPATION_TIME := 0.045

# Afterimages along the push axis, on hard punches only - at small sizes on a light punch
# they read as noise rather than speed.
const DIE_SMEAR_MIN_STRENGTH := 1.3
const DIE_SMEAR_COUNT := 2
const DIE_SMEAR_LIFETIME := 0.15
const DIE_SMEAR_ALPHA := 0.42

# Idle levitation. The die was the only motionless element on the character (it opts out of
# the sway shader, see _ensure_held_die), which is precisely what read as dead. Position
# only - scaling a ~38px sprite resamples its edges every frame and shimmers.
const DIE_BOB_AMPLITUDE := 4.0
const DIE_BOB_PERIOD := 3.0

# Die strike: on a big or lethal single-target hit the die itself is the weapon. Much
# shorter than the 0.95s thrown-dice ceremony - a throw is a mortar, this is a gunshot
# punctuating a decision the player already made.
const STRIKE_FLIGHT_TIME := 0.26
const STRIKE_ARC_HEIGHT := 46.0
const STRIKE_SCATTER := 10.0
const STRIKE_DRIVE_IN := 10.0          # px past the impact point, so it bites in
const STRIKE_DISSOLVE := 0.1
const STRIKE_REMATERIALIZE_DELAY := 0.2
const STRIKE_KILL_EMBED_HOLD := 0.1    # lethal only: a readable "die buried in the body" frame
const STRIKE_TUMBLE := 2.4             # radians over the flight
const STRIKE_SOUND := preload("res://whipsound.mp3")

# Taking a hit flinches the die too. A NEGATIVE punch strength is exactly a recoil: the same
# tween runs backwards along the thrust axis (away from the enemies, slightly down) and eases
# the die smaller instead of bigger. The die already flashes white with the body; moving it as
# well is what makes it read as something alive he is carrying rather than a pinned decal.
const DIE_FLINCH_STRENGTH := -0.35

@export var stats: CharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@onready var stats_ui: StatsUI = $StatsUI
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Hit-reaction state (knockback + squash), mirrors Enemy.take_damage.
# _body_move_tween is the SINGLE owner of self.position - both the hit knockback and the
# attack lunge build onto it, so the two can never tween the same property against each
# other. _body_rest_position is captured once, on the first move of either kind (at which
# point the body is guaranteed to be at rest), and is the only "home" either one returns to:
# re-reading position at that moment would capture a mid-lunge spot as home and the hero
# would walk off across the fight, one hit at a time.
var _body_move_tween: Tween
var _hit_squash_tween: Tween
var _body_rest_position: Vector2
var _body_rest_captured := false
var _hit_rest_sprite_scale: Vector2
var _hit_squash_active := false
var _sway_material: ShaderMaterial
var _ground_shadow: Sprite2D
# Held die: a bob node (idle levitation only) wrapping a pivot parked on the die's INK centre
# (so a punch scales/rotates about the die and not about the empty canvas centre it would
# otherwise orbit), and the sprite itself.
var _die_bob: Node2D
var _die_pivot: Node2D
var _die_sprite: Sprite2D
var _die_texture_cache: Dictionary = {}
var _die_rest_position: Vector2
var _die_punch_tween: Tween
var _die_tint_tween: Tween
var _die_bob_phase := 0.0
# Strike state. _die_strike_active gates re-entry (one die, one flight) and is cleared by
# both the normal landing and an idempotent failsafe, so the palm can never stay empty.
var _die_strike_active := false
var _die_strike_generation := 0
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

    # Bob wraps the pivot rather than sharing it: the idle levitation and the attack punch
    # are both position writes, and the punch snaps the pivot back to a canonical rest every
    # time it is interrupted. On one node the bob would be that snap's collateral damage.
    _die_bob = Node2D.new()
    _die_bob.name = "HeldDieBob"
    _die_bob_phase = randf() * TAU  # so it doesn't tick in lockstep with anything else
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
    _die_bob.add_child(_die_pivot)
    sprite_2d.get_parent().add_child(_die_bob)
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
    var tex := _die_texture_for(type)
    if _die_tint_tween and _die_tint_tween.is_valid():
        _die_tint_tween.kill()
    if not animate:
        if tex != null:
            _die_sprite.texture = tex
            _sync_held_die_transform()
        _die_sprite.modulate = Color.WHITE
        return
    # Same retune beat as the old tint: flash hot, settle. The swap happens AT the peak of
    # the flash, so the changeover is hidden inside the brightest frame rather than popping.
    _die_tint_tween = create_tween()
    _die_tint_tween.tween_property(_die_sprite, "modulate", DIE_RETUNE_FLASH, 0.09)         .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    if tex != null:
        _die_tint_tween.tween_callback(func() -> void:
            _die_sprite.texture = tex
            _sync_held_die_transform())
    _die_tint_tween.tween_property(_die_sprite, "modulate", Color.WHITE, 0.22)         .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Baked-per-type die art. An infusion overrides its type's accent, so it gets its own baked
# texture keyed by infusion id - that is what keeps the infusion-aware recolour the old
# modulate tint gave for free. Unknown type -> null, and the caller keeps the painted die.
func _die_texture_for(type: String) -> Texture2D:
    var key := type
    if Global.is_dice_infused(type):
        var info: Dictionary = DiceInfusions.get_info(type)
        if info.has("id"):
            key = String(info["id"])
    if _die_texture_cache.has(key):
        return _die_texture_cache[key]
    var tex := load(DIE_TEXTURE_DIR % key) as Texture2D
    _die_texture_cache[key] = tex
    return tex


# Thrust toward the enemies. Legs are grouped with .parallel() on the follow-up tweeners
# rather than set_parallel(true), which after a first step would fold the return INTO the
# outward step and play both at once.
func punch_held_die(strength: float = 1.0) -> void:
    if _die_pivot == null or _die_strike_active:
        return
    if _die_punch_tween and _die_punch_tween.is_valid():
        _die_punch_tween.kill()
        # A punch interrupted mid-flight leaves the pivot away from rest; snap the canonical
        # rest transform back before measuring the new one.
        _die_pivot.position = _die_rest_position

    var out_pos: Vector2 = _die_rest_position + DIE_PUNCH_OFFSET * strength
    var out_scale: Vector2 = Vector2.ONE * (1.0 + (DIE_PUNCH_SCALE - 1.0) * strength)
    var out_rot: float = DIE_PUNCH_ROTATION * strength

    if strength >= DIE_SMEAR_MIN_STRENGTH:
        _spawn_die_smear(out_pos)

    _die_punch_tween = create_tween()
    # Anticipation, as its own SEQUENTIAL step ahead of the push. .parallel() applies to the
    # tweener that comes AFTER it, so the push block below still groups correctly.
    var back_pos: Vector2 = _die_rest_position + DIE_PUNCH_OFFSET * strength * DIE_ANTICIPATION_FRAC
    _die_punch_tween.tween_property(_die_pivot, "position", back_pos, DIE_ANTICIPATION_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _die_punch_tween.parallel().tween_property(_die_pivot, "scale",
            Vector2.ONE * DIE_ANTICIPATION_SCALE, DIE_ANTICIPATION_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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


# Afterimages along the push axis. Sprites, never a material (the sway shader discards
# modulate - see _ensure_held_die), each on its OWN tween so it outlives the punch that
# spawned it, and freed by that tween rather than by anything on the rig.
func _spawn_die_smear(out_pos: Vector2) -> void:
    if _die_sprite == null or _die_sprite.texture == null or _die_bob == null:
        return
    for i in DIE_SMEAR_COUNT:
        var t: float = float(i + 1) / float(DIE_SMEAR_COUNT + 1)
        var ghost := Sprite2D.new()
        ghost.texture = _die_sprite.texture
        ghost.position = _die_sprite.position
        ghost.scale = _die_sprite.scale
        var tint: Color = _die_sprite.modulate
        tint.a = DIE_SMEAR_ALPHA * (1.0 - t * 0.45)
        ghost.modulate = tint
        var holder := Node2D.new()
        holder.position = _die_rest_position.lerp(out_pos, t)
        holder.add_child(ghost)
        _die_bob.add_child(holder)
        _die_bob.move_child(holder, 0)  # behind the real die
        var tw := holder.create_tween()
        tw.tween_property(ghost, "modulate:a", 0.0, DIE_SMEAR_LIFETIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.tween_callback(holder.queue_free)


# Ladder entry point: one rung drives the punch AND the lunge, so the hero's whole body
# answers a 40-damage haymaker differently from a 3-damage poke - the last feel element in
# the game that was still flat regardless of what it hit.
func punch_held_die_for_impact(impact: int) -> void:
    var idx: int = clampi(impact, 0, DIE_PUNCH_TIER_STRENGTH.size() - 1)
    # Typed on purpose: indexing a const Array yields Variant, and `:=` on a Variant is the
    # parse error that takes the whole file down while gdtoolkit reports it clean.
    var strength: float = DIE_PUNCH_TIER_STRENGTH[idx]
    punch_held_die(strength)
    lunge_body(strength)


# --- Body lunge ---------------------------------------------------------------------------
# Shares _body_move_tween with the hit knockback (see the var block): whichever fires last
# owns the property, and both return to the same canonical rest, so an attack played while
# being hit still ends the hero exactly where he started.
func lunge_body(strength: float = 1.0) -> void:
    _capture_body_rest()
    if _body_move_tween and _body_move_tween.is_valid():
        _body_move_tween.kill()

    var out_pos: Vector2 = _body_rest_position + LUNGE_OFFSET * strength
    _body_move_tween = create_tween()
    _body_move_tween.tween_property(self, "position", out_pos, LUNGE_OUT) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _body_move_tween.tween_property(self, "position", _body_rest_position, LUNGE_BACK) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Captured on the first body move of the run, when nothing has displaced the hero yet.
func _capture_body_rest() -> void:
    if not _body_rest_captured:
        _body_rest_position = position
        _body_rest_captured = true


func _process(delta: float) -> void:
    # Idle levitation. Driven here rather than by a looping Tween: a loop restarts at its leg
    # boundary, which is exactly what makes independent breathers drift into lockstep.
    if _die_bob == null:
        return
    _die_bob_phase += delta * TAU / DIE_BOB_PERIOD
    _die_bob.position.y = sin(_die_bob_phase) * DIE_BOB_AMPLITUDE


# --- Die strike ----------------------------------------------------------------------------
# The die itself is the weapon on a big or lethal single-target hit: it launches from the
# palm, smashes the body, and the damage lands ON that impact (damage_effect.gd defers the
# whole hit bundle into on_impact). The clone-flight pattern - hide the real one, fly a
# duplicate on its own tweens, restore behind a failsafe - is the same one the played card,
# the scout pick and the refuel return all use.
#
# Returns false if it cannot run (no die overlay after an art swap, already striking, dead
# target), and the caller then resolves the hit immediately as before. Never assume it ran.
func strike_with_die(target: Node, on_impact: Callable, lethal: bool = false) -> bool:
    if _die_sprite == null or _die_pivot == null or _die_bob == null:
        return false
    if _die_strike_active or _debug_hero_override_active:
        return false
    if target == null or not is_instance_valid(target) or not (target is Node2D):
        return false
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if parent_layer == null:
        return false

    var to_pos: Vector2 = Card.thrown_impact_pos(target) + Vector2(
            randf_range(-STRIKE_SCATTER, STRIKE_SCATTER),
            randf_range(-STRIKE_SCATTER, STRIKE_SCATTER))
    var from_pos: Vector2 = _die_pivot.global_position

    _die_strike_active = true
    _die_strike_generation += 1
    var generation := _die_strike_generation

    if _die_punch_tween and _die_punch_tween.is_valid():
        _die_punch_tween.kill()
    _die_pivot.position = _die_rest_position
    _die_pivot.scale = Vector2.ONE
    _die_pivot.rotation = 0.0
    _die_pivot.visible = false

    # A duplicate of the whole pivot subtree, so the clone inherits the ink-centre offset and
    # can be positioned by its ink centre exactly like the real rig. flags 0 = geometry only,
    # no signals or groups riding along.
    var clone := _die_pivot.duplicate(0) as Node2D
    clone.visible = true
    clone.z_index = 150  # ui_layer flourish convention, above the flying card's 100
    parent_layer.add_child(clone)
    clone.global_position = from_pos

    # The body throws it: lunge now, at full strength, whatever the punch ladder said.
    lunge_body(1.0)
    SFXPlayer.play(STRIKE_SOUND, false, randf_range(1.15, 1.3), -6.0)

    var arc_from := from_pos
    var arc_to := to_pos
    var step := func(t: float) -> void:
        if not is_instance_valid(clone):
            return
        # Quadratic bezier through a raised control point: rises out of the palm, falls into
        # the body, rather than sliding along a straight line.
        var control := arc_from.lerp(arc_to, 0.5) + Vector2(0.0, -STRIKE_ARC_HEIGHT)
        var a := arc_from.lerp(control, t)
        var b := control.lerp(arc_to, t)
        clone.global_position = a.lerp(b, t)
        clone.rotation = t * STRIKE_TUMBLE

    var fly := clone.create_tween()
    fly.tween_method(step, 0.0, 1.0, STRIKE_FLIGHT_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly.tween_callback(func() -> void:
        _on_strike_landed(clone, target, to_pos, on_impact, lethal, generation)
    )

    # Idempotent failsafe: whatever happens to the clone or the target, the palm refills.
    var failsafe := get_tree().create_timer(
            STRIKE_FLIGHT_TIME + STRIKE_KILL_EMBED_HOLD + STRIKE_DISSOLVE
            + STRIKE_REMATERIALIZE_DELAY + 0.6, false)
    failsafe.timeout.connect(func() -> void: _restore_held_die(generation))
    return true


func _on_strike_landed(clone: Node2D, target: Node, to_pos: Vector2, on_impact: Callable,
        lethal: bool, generation: int) -> void:
    # The damage bundle first: it owns the slash, the flash, the hit-stop and the number, so
    # the freeze punctuates the landing instead of stranding the flight.
    if on_impact.is_valid():
        on_impact.call()

    if is_instance_valid(clone):
        var drive := to_pos
        if target != null and is_instance_valid(target) and target is Node2D:
            drive = to_pos + (to_pos - clone.global_position).normalized() * STRIKE_DRIVE_IN
        var hold: float = STRIKE_KILL_EMBED_HOLD if lethal else 0.0
        var out := clone.create_tween()
        out.tween_property(clone, "global_position", drive, 0.05) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        # On a kill the die stays buried for a beat, so there is a readable frame of "his die
        # is in them" right as the body bursts into dice shards.
        if hold > 0.0:
            out.tween_interval(hold)
        out.tween_property(clone, "scale", Vector2.ZERO, STRIKE_DISSOLVE) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        out.parallel().tween_property(clone, "modulate:a", 0.0, STRIKE_DISSOLVE) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        out.tween_callback(clone.queue_free)

    var back := get_tree().create_timer(STRIKE_REMATERIALIZE_DELAY, false)
    back.timeout.connect(func() -> void: _restore_held_die(generation))


# Re-forms the die in the palm using the retune language (flash toward white, settle into the
# current accent). Guarded by generation so a stale failsafe from a previous strike cannot
# yank a newer one out of the air, and idempotent so both the normal path and the failsafe
# can call it.
func _restore_held_die(generation: int) -> void:
    if generation != _die_strike_generation or not _die_strike_active:
        return
    _die_strike_active = false
    if _die_pivot == null or _die_sprite == null:
        return
    _die_pivot.position = _die_rest_position
    _die_pivot.scale = Vector2.ONE
    _die_pivot.rotation = 0.0
    _die_pivot.visible = true
    _update_die_tint(true)
    punch_held_die(DIE_RETUNE_PUNCH)


func _on_active_dice_changed(active_dice) -> void:
    _update_die_tint(true, String(active_dice))
    punch_held_die(DIE_RETUNE_PUNCH)


func _on_card_played(card: Card) -> void:
    # Attacks only, matching the gate that spawns the directional slash on the enemy
    # (card.gd) - so the thrust and the cut that lands ~0.055s later read as one beat, and a
    # block or a blessing does not get a phantom attack tell.
    # Baseline floor, deliberately kept even though damage_effect.gd upgrades this a moment
    # later on the same frame: cards whose damage is entirely timer-deferred (Flurry,
    # Stampede, the thrown-dice cards) never produce a same-frame hit, and without this they
    # would lose their thrust entirely.
    if card != null and card.type == Card.Type.ATTACK:
        punch_held_die()
        lunge_body()


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
    # Toggled on the BOB, not the pivot: the pivot's visibility belongs to the strike (which
    # hides the real die while its clone is in the air), and two owners on one flag would
    # have the A/B swap and a landing strike undoing each other.
    if _die_bob != null:
        _die_bob.visible = not _debug_hero_override_active


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
    # Shares the body's single position tween slot with the attack lunge, and the same
    # canonical rest - so being hit mid-lunge (or lunging mid-recoil) still lands the hero
    # back exactly where he started instead of adopting a mid-animation spot as home.
    _capture_body_rest()
    if not _hit_squash_active:
        _hit_rest_sprite_scale = sprite_2d.scale
        _hit_squash_active = true

    if _body_move_tween and _body_move_tween.is_valid():
        _body_move_tween.kill()
    if _hit_squash_tween and _hit_squash_tween.is_valid():
        _hit_squash_tween.kill()

    # Player sits to the left of the enemies, so recoils leftward (-x).
    _body_move_tween = create_tween()
    _body_move_tween.tween_property(self, "position", _body_rest_position + Vector2(-16, 0), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _body_move_tween.tween_property(self, "position", _body_rest_position, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    _hit_squash_tween = create_tween()
    _hit_squash_tween.tween_property(sprite_2d, "scale", Vector2(_hit_rest_sprite_scale.x * 1.15, _hit_rest_sprite_scale.y * 0.85), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_squash_tween.tween_property(sprite_2d, "scale", _hit_rest_sprite_scale, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    # Released so the next hit re-reads the resting scale: the debug hero swap rewrites
    # sprite_2d.scale, and a value cached before that swap would squash to the wrong size.
    _hit_squash_tween.tween_callback(func(): _hit_squash_active = false)

    # The die recoils with him. Routed through punch_held_die so it shares the one tween slot
    # on the pivot (and inherits its guard: a die that is currently mid-strike stays in the
    # air rather than being yanked back to the palm to flinch).
    punch_held_die(DIE_FLINCH_STRENGTH)

func _on_event_damage(amount):
    print("taking damage from event")
