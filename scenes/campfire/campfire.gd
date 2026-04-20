extends Control
var character_stats: CharacterStats
var run_stats: RunStats
var tooltip_instance: CanvasLayer
const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
var _hover_id := 0

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func _on_heal_button_pressed() -> void:
    print("healing")
    var campfire_heal = 15
    character_stats.health += campfire_heal
    var campfire_heal_sound = preload("res://sounds/fountainheal.wav")
    SFXPlayer.play(campfire_heal_sound)
    Events.hp_changed.emit()
    Events.campfire_exited.emit()

func _on_heal_zone_mouse_entered() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null

    _hover_id += 1
    var my_id := _hover_id

    await get_tree().create_timer(0.5).timeout

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    var tooltip = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip)
    var tooltip_panel = tooltip.get_node("Tooltip")
    tooltip_panel.get_tooltip_content("REST")

    var pos = get_global_mouse_position() + Vector2(24, 24)
    pos = pos.round()
    tooltip_panel.show_tooltip(pos)
    tooltip_instance = tooltip

func _on_heal_zone_mouse_exited() -> void:
    _hover_id += 1
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null


func _on_heal_button_mouse_entered() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null

    _hover_id += 1
    var my_id := _hover_id

    await get_tree().create_timer(0.5).timeout

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    var tooltip = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip)
    var tooltip_panel = tooltip.get_node("Tooltip")
    tooltip_panel.get_tooltip_content("REST")

    var pos = get_global_mouse_position() + Vector2(24, 24)
    pos = pos.round()
    tooltip_panel.show_tooltip(pos)
    tooltip_instance = tooltip

func _on_heal_button_mouse_exited() -> void:
    _hover_id += 1
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
