class_name MapRoom
extends Area2D

signal selected (room: Room)
# Emitted the instant the player clicks - unlike `selected`, which the "select"
# animation delays by 0.6s before run.gd swaps views. The map uses this to start
# the pawn's travel hop inside that built-in wait instead of after it.
signal pick_started (room: Room)

# [texture, size multiplier]. The multiplier was dead data before - nothing ever read
# ICONS[type][1], so every icon rendered at the scene's flat 0.15 and their on-screen
# sizes were whatever their source art happened to be. Measured, that ranged from 52px
# (shop) to 84px (event), i.e. the event "?" was 60% taller than its neighbours - which
# is most of why it read as "big & purple". These multipliers normalize every regular
# room to ~60px on its longest axis; the boss keeps its own much larger footprint.
# Tuning any single icon's presence is now a one-number change here.
const ICONS := {
    Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
    Room.Type.MONSTER: [preload("res://fight_icon_v3.png"), Vector2(0.415, 0.415)],
    # Elite runs deliberately over the ~60px norm (it renders 57x70). Its art is three
    # separate thin pieces - sword, head, medallion - rather than one solid object like
    # every other icon, so at matched long-axis size it had the LEAST painted area in the
    # set (1566px vs 1789-2444) despite being the highest-stakes non-boss room. 1.05 puts
    # it at ~2133, mid-pack, without touching the art itself.
    Room.Type.ELITE: [preload("res://elite_fight_icon_v2.png"), Vector2(1.05, 1.05)],
    Room.Type.CAMPFIRE: [preload("res://campfire_icon_v2.png"), Vector2(0.457, 0.457)],
    # Deliberately NOT the same file as the treasure room's chest (treasurenobg.png).
    # The room needs a matched closed/open pair for its opening animation, and only a
    # closed version of this brighter chest exists - so the map gets the new art and the
    # room keeps its matching pair until an open version is made.
    Room.Type.TREASURE: [preload("res://treasure_icon_v2.png"), Vector2(0.432, 0.432)],
    Room.Type.SHOP: [preload("res://shop_icon_v3.png"), Vector2(0.458, 0.458)],
    Room.Type.BOSS: [preload("res://boss_icon_v3.png"), Vector2.ONE],
    # v10 = carved wooden "?" (2026-07-27). The "?" IS the silhouette here, which is what
    # makes it read at map size; v9 was a flat UI glyph and the round-1 signpost/scroll
    # candidates buried their "?" inside a bigger object and became unreadable. Slightly
    # above the 60px norm because a "?" is narrow and full of holes, so it needs the extra
    # height to carry the same visual weight as the wide icons next to it.
    Room.Type.EVENT: [preload("res://event_icon_v11.png"), Vector2(0.441, 0.441)],
}

const BASE_ICON_SCALE := 0.15

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var visuals: Node2D = $Visuals
@onready var line_2d: Line2D = $Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var affordable_badge: Area2D = $AffordableBadge

const HOVER_SCALE := Vector2(1.12, 1.12)
const HOVER_IN_DURATION := 0.12
const HOVER_OUT_DURATION := 0.12

# Selection feedback: quick scale punch on the root (hover also owns root scale - the
# two never run at the same time, the punch just replaces any hover tween) plus a
# one-shot additive gold burst, filling the previously-silent 0.6s select delay.
const SELECT_PUNCH_SCALE := Vector2(1.22, 1.22)
const SELECT_FLASH_COLOR := Color(1.0, 0.82, 0.38)

# The radial-light texture/material below are still used for the pawn's ground shadow
# and the one-shot select flash. There is deliberately NO ambient glow on available
# rooms: an additive halo under every clickable room was tried and rejected (Julien:
# "we already have the highlight where they blink in size and the glow looks bad") -
# the AnimationPlayer scale pulse is the availability cue, on its own.

const RELEVANCE_TINT_TIME := 0.3

# "Circled in ink" marker on rooms you've taken, replacing the flat orange compass
# circle. Drawn as an open, wobbling pen stroke that overshoots past its own start
# (RING_END_ANGLE > 1.0) with a tapered width - reads as an annotation somebody drew on
# the map rather than a UI ring, which is the whole fantasy of the parchment sheet.
const RING_COLOR := Color("#4a2f14")
const RING_WIDTH := 9.0
const RING_POINTS := 56
const RING_START_ANGLE := -0.07
const RING_END_ANGLE := 1.06
const RING_WOBBLE := 0.045
const RING_DRAW_TIME := 0.45

const AFFORDABLE_BADGE_TOOLTIP_TEXT := "You have enough gold to buy a Dice in the shop. It doesn't mean you always should! Sometimes, saving up for another Dice is worth it."
const AFFORDABLE_BADGE_TOOLTIP_SCENE := "res://scenes/ui/icon_tooltip.tscn"

# Placeholder sounds (flagged to Julien): soft pluck tick on hover (the decorative
# orb-land plink, priority -1 so it can never steal a real sound) and a die-clack on
# select - "placing your die on the board".
const HOVER_SFX := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const SELECT_SFX := preload("res://sounds/dicerollsound3.mp3")

var available := false : set = set_available
var room: Room : set = set_room
var _hover_tween: Tween
var _entrance_tween: Tween
var _tint_tween: Tween
var _ring_tween: Tween
var _ring_points := PackedVector2Array()
var _showing_affordable_badge := false
var _affordable_badge_tooltip: Node

static var _shared_glow_texture: Texture2D
static var _shared_glow_material: CanvasItemMaterial
static var _shared_ring_width_curve: Curve


func _ready() -> void:
    var test_room := Room.new()
    test_room.type = Room.Type.MONSTER
    test_room.position = Vector2(500, 500)
    room = test_room
    _setup_ring()
    _make_circle(55.0)
    line_2d.visible = false


func set_available(new_value: bool) -> void:
    available = new_value

    if available:
        animation_player.play("highlight")
    elif not room.selected:
        animation_player.play("RESET")

func set_room(new_data: Room) -> void:
    room = new_data
    position = room.position
    line_2d.rotation_degrees = randi_range(0, 360)
    sprite_2d.texture = ICONS[room.type][0]
    sprite_2d.scale = BASE_ICON_SCALE * (ICONS[room.type][1] as Vector2)

    var new_shape = $CollisionShape2D.shape.duplicate()
    $CollisionShape2D.shape = new_shape

    if room.type == Room.Type.BOSS:
        $CollisionShape2D.shape.radius = 120.0
        _make_circle(120)
    else:
        $CollisionShape2D.shape.radius = 44.83
        _make_circle(55)
# Instant version, for rooms that were already walked when the map is (re)built -
# loading a save or coming back to the map shouldn't re-draw old annotations.
func show_selected() -> void:
    line_2d.visible = true
    # The RESET animation parks Line2D:modulate at alpha 0 - anything that reveals the
    # ring has to put the alpha back (the ring's own color lives in default_color).
    line_2d.modulate = Color.WHITE
    line_2d.points = _ring_points


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
    if not available or not event.is_action_pressed("left_mouse"):
        return

    pick_started.emit(room)

    # Mark selected BEFORE clearing availability: set_available(false) plays RESET on a
    # room that isn't selected yet, which would zero the ring's modulate alpha out from
    # under the draw-on we're about to start.
    room.selected = true
    # Prevent double-clicking by immediately disabling this room
    available = false

    animation_player.play("select")
    line_2d.visible = true
    line_2d.modulate = Color.WHITE
    _animate_ring_draw()
    _play_select_feedback()


# The circle is drawn ON at pick time rather than just appearing - the stroke sweeps
# around the room like someone marking the map, and it fits inside the 0.6s the select
# animation already waits before the view changes.
func _animate_ring_draw() -> void:
    if _ring_tween and _ring_tween.is_valid():
        _ring_tween.kill()
    line_2d.points = PackedVector2Array()
    _ring_tween = create_tween()
    _ring_tween.tween_method(_set_ring_progress, 0.0, 1.0, RING_DRAW_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_ring_progress(progress: float) -> void:
    var count := int(round(progress * _ring_points.size()))
    if count < 2:
        line_2d.points = PackedVector2Array()
        return
    line_2d.points = _ring_points.slice(0, count)


func _on_map_room_selected() -> void:
    selected.emit(room)


# Small "you can afford a Dice" reminder shown on every currently-clickable room, driven by
# Map.refresh_affordable_badges() (same Global.gold >= Global.cheapest_dice_price threshold as
# the top-bar Dice Shop glow) - meant to catch the player right before they commit to a room,
# not just on the shop icon itself which is easy to miss on the way to a fight.
func set_show_affordable_badge(value: bool) -> void:
    if value == _showing_affordable_badge:
        return
    _showing_affordable_badge = value
    affordable_badge.visible = value
    if not value:
        _hide_affordable_badge_tooltip()


# Same instantiate-on-hover/free-on-exit tooltip lifecycle as every other tooltip in the
# project (see the "Tooltip leak pattern" note) - IconTooltip.show_tooltip() takes a raw
# screen-space position rather than a Control (unlike its spawn_below() convenience wrapper),
# which is what we need here since the badge lives in the Map's scrolled/zoomed world space,
# not under a CanvasLayer.
func _on_affordable_badge_mouse_entered() -> void:
    if not _showing_affordable_badge:
        return
    _hide_affordable_badge_tooltip()
    var layer: Node = load(AFFORDABLE_BADGE_TOOLTIP_SCENE).instantiate()
    get_tree().root.add_child(layer)
    var panel: IconTooltip = layer.get_node("IconTooltip")
    var screen_pos: Vector2 = get_viewport().get_canvas_transform() * affordable_badge.global_position
    panel.show_body_tooltip(screen_pos, AFFORDABLE_BADGE_TOOLTIP_TEXT)
    _affordable_badge_tooltip = layer


func _on_affordable_badge_mouse_exited() -> void:
    _hide_affordable_badge_tooltip()


func _hide_affordable_badge_tooltip() -> void:
    if is_instance_valid(_affordable_badge_tooltip):
        _affordable_badge_tooltip.queue_free()
    _affordable_badge_tooltip = null


func _exit_tree() -> void:
    _hide_affordable_badge_tooltip()

# Pen-stroke styling for the "you took this room" ring: round caps/joints and a width
# curve that starts thin, swells through the body and thins out again, so the overshoot
# tail tapers off like a pen leaving the paper.
func _setup_ring() -> void:
    line_2d.default_color = RING_COLOR
    line_2d.width = RING_WIDTH
    line_2d.closed = false
    line_2d.joint_mode = Line2D.LINE_JOINT_ROUND
    line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
    line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
    line_2d.width_curve = _get_ring_width_curve()


static func _get_ring_width_curve() -> Curve:
    if _shared_ring_width_curve == null:
        var curve := Curve.new()
        curve.add_point(Vector2(0.0, 0.3))
        curve.add_point(Vector2(0.18, 1.0))
        curve.add_point(Vector2(0.8, 1.0))
        curve.add_point(Vector2(1.0, 0.25))
        _shared_ring_width_curve = curve
    return _shared_ring_width_curve


# Open, hand-drawn circle rather than a compass-perfect one: two low-frequency
# harmonics with a per-room random phase wobble the radius, a slight squash breaks the
# symmetry, and the arc runs past its own starting point so the stroke crosses itself.
# No two rooms get the same circle.
func _make_circle(radius: float, points: int = RING_POINTS) -> void:
    var built := PackedVector2Array()
    var phase_a := randf() * TAU
    var phase_b := randf() * TAU
    var squash := 1.0 + randf_range(-0.05, 0.05)
    for i in range(points + 1):
        var t := float(i) / points
        var angle: float = lerpf(RING_START_ANGLE, RING_END_ANGLE, t) * TAU
        var wobble := 1.0 + (sin(angle * 2.0 + phase_a) * 0.6 + sin(angle * 3.0 + phase_b) * 0.4) * RING_WOBBLE
        var r := radius * wobble
        built.append(Vector2(cos(angle) * r, sin(angle) * r * squash))
    _ring_points = built
    line_2d.points = built


# =========================================================
# RELEVANCE TINT (Map._refresh_room_relevance)
# =========================================================

# Brightness-multiply dim on Visuals only (the card-dimming convention - never
# alpha-fade). The gold ring (Line2D) and the availability glow are siblings of
# Visuals, so a dimmed walked room keeps its full-brightness trail ring.
func set_relevance_tint(tint: Color) -> void:
    if visuals.modulate.is_equal_approx(tint):
        return
    if _tint_tween and _tint_tween.is_valid():
        _tint_tween.kill()
    _tint_tween = create_tween()
    _tint_tween.tween_property(visuals, "modulate", tint, RELEVANCE_TINT_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =========================================================
# ENTRANCE REVEAL (Map._play_entrance_reveal)
# =========================================================

# Root-channel only (modulate:a + root scale) so it can't fight the pulse
# (AnimationPlayer owns Visuals:scale) or the relevance tint (Visuals:modulate).
# Root scale is shared with hover/select - those call _finish_entrance() first.
func play_entrance(delay: float) -> void:
    if _entrance_tween and _entrance_tween.is_valid():
        _entrance_tween.kill()
    modulate.a = 0.0
    scale = Vector2(0.4, 0.4)
    _entrance_tween = create_tween().set_parallel(true)
    _entrance_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)
    _entrance_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_delay(delay) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_entrance() -> void:
    if _entrance_tween and _entrance_tween.is_valid():
        _entrance_tween.kill()
        modulate.a = 1.0
        scale = Vector2.ONE


# =========================================================
# AVAILABILITY GLOW
# =========================================================

static func _get_glow_texture() -> Texture2D:
    if _shared_glow_texture == null:
        var gradient := Gradient.new()
        gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
        gradient.colors = PackedColorArray([
            Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.0),
        ])
        var texture := GradientTexture2D.new()
        texture.gradient = gradient
        texture.width = 256
        texture.height = 256
        texture.fill = GradientTexture2D.FILL_RADIAL
        texture.fill_from = Vector2(0.5, 0.5)
        texture.fill_to = Vector2(0.5, 0.0)
        _shared_glow_texture = texture
    return _shared_glow_texture


static func _get_glow_material() -> CanvasItemMaterial:
    if _shared_glow_material == null:
        var material := CanvasItemMaterial.new()
        material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        _shared_glow_material = material
    return _shared_glow_material


# =========================================================
# SELECT FEEDBACK
# =========================================================

func _play_select_feedback() -> void:
    SFXPlayer.play(SELECT_SFX, false, 0.92 + randf() * 0.08, -4.0)
    _finish_entrance()
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", SELECT_PUNCH_SCALE, 0.09) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hover_tween.tween_property(self, "scale", Vector2.ONE, 0.2) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    var flash := Sprite2D.new()
    flash.texture = _get_glow_texture()
    flash.material = _get_glow_material()
    flash.modulate = Color(SELECT_FLASH_COLOR, 0.85)
    flash.scale = Vector2(0.55, 0.55)
    flash.z_index = 3
    add_child(flash)
    var flash_tween := flash.create_tween().set_parallel(true)
    flash_tween.tween_property(flash, "scale", Vector2(0.85, 0.85), 0.3) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    flash_tween.chain().tween_callback(flash.queue_free)


# Extra hover "pop" on top of the ambient highlight pulse (AnimationPlayer scales Visuals,
# not the root) - scaling the root node here instead avoids fighting that looping animation.
# Gated on `available` so it only responds on rooms that are actually clickable right now.
func _on_mouse_entered() -> void:
    if not available:
        return
    _finish_entrance()
    SFXPlayer.play(HOVER_SFX, false, 1.4 + randf() * 0.15, -13.0, -1)
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", HOVER_SCALE, HOVER_IN_DURATION) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
    _finish_entrance()
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", Vector2.ONE, HOVER_OUT_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
