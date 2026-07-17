class_name MapRoom
extends Area2D

signal selected (room: Room)

const ICONS := {
    Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
    Room.Type.MONSTER: [preload("res://normal_fight_icon_v2.png"), Vector2.ONE],
    Room.Type.ELITE: [preload("res://elite_fight_icon_v2.png"), Vector2.ONE],
    Room.Type.CAMPFIRE: [preload("res://campfire_icon.png"), Vector2.ONE],    
    Room.Type.TREASURE: [preload("res://treasurenobg.png"), Vector2.ONE],
    Room.Type.SHOP: [preload("res://shop_icon_nano3.png"), Vector2.ONE],
    Room.Type.BOSS: [preload("res://boss_icon_v3.png"), Vector2(1.6, 1.6)],
    Room.Type.EVENT: [preload("res://event_icon_v9.png"), Vector2.ONE],
}

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var affordable_badge: Area2D = $AffordableBadge

const HOVER_SCALE := Vector2(1.12, 1.12)
const HOVER_IN_DURATION := 0.12
const HOVER_OUT_DURATION := 0.12

const AFFORDABLE_BADGE_TOOLTIP_TEXT := "You have enough gold to buy a Dice in the shop. It doesn't mean you always should! Sometimes, saving up for another Dice is worth it."
const AFFORDABLE_BADGE_TOOLTIP_SCENE := "res://scenes/ui/icon_tooltip.tscn"

var available := false : set = set_available
var room: Room : set = set_room
var _hover_tween: Tween
var _showing_affordable_badge := false
var _affordable_badge_tooltip: Node

func _ready() -> void:
    var test_room := Room.new()
    test_room.type = Room.Type.MONSTER
    test_room.position = Vector2(500, 500)
    room = test_room
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

    var new_shape = $CollisionShape2D.shape.duplicate()
    $CollisionShape2D.shape = new_shape

    if room.type == Room.Type.BOSS:
        $CollisionShape2D.shape.radius = 120.0
        _make_circle(120)
    else:
        $CollisionShape2D.shape.radius = 44.83
        _make_circle(55)
func show_selected() -> void:
    line_2d.visible = true
    line_2d.modulate = Color("#f0c040")


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
    if not available or not event.is_action_pressed("left_mouse"):
        return

    # Prevent double-clicking by immediately disabling this room
    available = false

    print("selected")
    room.selected = true
    animation_player.play("select")
    line_2d.visible = true
    line_2d.modulate = Color("#f0c040")


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

func _make_circle(radius: float, points: int = 32) -> void:
    line_2d.clear_points()
    for i in range(points + 1):
        var angle := (float(i) / points) * TAU
        line_2d.add_point(Vector2(cos(angle), sin(angle)) * radius)


# Extra hover "pop" on top of the ambient highlight pulse (AnimationPlayer scales Visuals,
# not the root) - scaling the root node here instead avoids fighting that looping animation.
# Gated on `available` so it only responds on rooms that are actually clickable right now.
func _on_mouse_entered() -> void:
    if not available:
        return
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", HOVER_SCALE, HOVER_IN_DURATION) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", Vector2.ONE, HOVER_OUT_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
