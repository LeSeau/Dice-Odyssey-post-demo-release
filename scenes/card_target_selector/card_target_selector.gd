extends Node2D

const ARC_POINTS := 8

@onready var area_2d: Area2D = $Area2D
@onready var card_arc: Line2D = $CanvasLayer/CardArc

var current_card: CardUI
var targeting := false
var locked_on := false


func _ready() -> void:
    Events.card_aim_started.connect(_on_card_aim_started)
    Events.card_aim_ended.connect(_on_card_aim_ended)


func _process(_delta: float) -> void:
    if not targeting:
        return
    if not is_instance_valid(current_card):
        return
    area_2d.position = get_local_mouse_position()
    card_arc.points = _get_points()


func _get_points() -> Array:
    var points := []
    var start := current_card.global_position
    start.x += (current_card.size.x / 2)
    if(Global.playing_red_card):
        start.x+=40
    var target := get_local_mouse_position()
    var distance := (target - start)
    
    for i in ARC_POINTS:
        var t := (1.0 / ARC_POINTS) * i
        var x := start.x + (distance.x / ARC_POINTS) * i
        var y := start.y + ease_out_cubic(t) * distance.y
        points.append(Vector2(x, y))
    
    points.append(target)
    
    return points


func ease_out_cubic(number : float) -> float:
    return 1.0 - pow(1.0 - number, 3.0)


func _on_card_aim_started(card: CardUI) -> void:
    if not card.card.is_single_targeted() :

        return

    # Safety net: clear any stray highlight left over from a previous aim
    # cycle (e.g. an interrupted fade) before starting a fresh one, rather
    # than trying to track down every possible leak individually.
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy.has_method("set_target_highlight"):
            enemy.set_target_highlight(false)

    targeting = true
    area_2d.monitoring = true
    area_2d.monitorable = true
    current_card = card
    locked_on = false
    card_arc.modulate = Color(1, 1, 1, 1)
    card_arc.scale = Vector2(1.0, 1.0)


func _on_card_aim_ended(card: CardUI) -> void:
    targeting = false
    card_arc.clear_points()
    area_2d.position = Vector2.ZERO
    area_2d.monitoring = false
    area_2d.monitorable = false
    if is_instance_valid(card):
        for target in card.targets:
            if is_instance_valid(target) and target.has_method("set_target_highlight"):
                target.set_target_highlight(false)
    current_card = null



func _on_area_2d_area_entered(area: Area2D) -> void:
    if not current_card or not targeting:
        return

    if not current_card.targets.has(area):
        current_card.targets.append(area)

    if area.has_method("set_target_highlight"):
        area.set_target_highlight(true)

    # Damage previews (get_dynamic_description) read whichever enemy is first in
    # current_card.targets - refresh now that it changed, so e.g. an Exposed enemy's +50%
    # incoming damage shows up in the card text the moment you aim at them, not just on the
    # next dice-roll-driven refresh.
    if current_card.has_method("_on_dice_rolled_update_description"):
        current_card._on_dice_rolled_update_description()

    _set_locked_on(true)


func _on_area_2d_area_exited(area: Area2D) -> void:
    if not current_card or not targeting:
        return

    current_card.targets.erase(area)

    if area.has_method("set_target_highlight"):
        area.set_target_highlight(false)

    if current_card.has_method("_on_dice_rolled_update_description"):
        current_card._on_dice_rolled_update_description()

    _set_locked_on(not current_card.targets.is_empty())


func _set_locked_on(value: bool) -> void:
    if value == locked_on:
        return
    locked_on = value

    var target_color := Color(2.4, 2.0, 0.7, 1) if value else Color(1, 1, 1, 1)

    var tween := create_tween()
    tween.tween_property(card_arc, "modulate", target_color, 0.08)
