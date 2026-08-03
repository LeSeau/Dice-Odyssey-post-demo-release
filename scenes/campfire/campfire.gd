extends Control
var character_stats: CharacterStats
var run_stats: RunStats
var tooltip_instance: CanvasLayer
const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
var _hover_id := 0

# Percentage of current Max HP, not a flat amount - so the heal scales with any
# permanent Max HP changes the run has picked up (Hollow Idol, Patient Monk...)
# instead of staying pinned to the starting 66 HP value forever.
const CAMPFIRE_HEAL_PERCENT := 0.33

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func _get_campfire_heal_amount() -> int:
    return roundi(character_stats.max_health * CAMPFIRE_HEAL_PERCENT)

# Bypasses tooltip.gd's generic get_tooltip_content("REST") (a static "Heal 22 HP"
# string shared by keyword tooltips elsewhere) so the tooltip shows the actual
# amount this Rest will heal for THIS character's current Max HP, not a stale flat
# number. Same title styling as get_tooltip_content() for visual consistency.
func _set_rest_tooltip_content(tooltip_panel) -> void:
    tooltip_panel.tooltip_title.text = "[color=gold][b]REST[/b][/color]"
    tooltip_panel.tooltip_label.text = "Heal %d HP (%d%% of Max HP)" % [_get_campfire_heal_amount(), roundi(CAMPFIRE_HEAL_PERCENT * 100)]

func _on_heal_button_pressed() -> void:
    var campfire_heal := _get_campfire_heal_amount()
    character_stats.health += campfire_heal
    var campfire_heal_sound = preload("res://sounds/fountainheal.wav")
    SFXPlayer.play(campfire_heal_sound)
    Events.hp_changed.emit()
    Events.campfire_exited.emit()

func _on_upgrade_button_pressed() -> void:
    Events.open_deck_view_for_upgrade.emit()

func _on_upgrade_button_mouse_entered() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null

    _hover_id += 1
    var my_id := _hover_id

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    var tooltip = TooltipScene.instantiate()
    Global.add_tooltip(tooltip, self)
    var tooltip_panel = tooltip.get_node("Tooltip")
    tooltip_panel.get_tooltip_content("UPGRADE")

    var pos = get_global_mouse_position() + Vector2(24, 24)
    pos = pos.round()
    tooltip_panel.show_tooltip(pos)
    tooltip_instance = tooltip

func _on_upgrade_button_mouse_exited() -> void:
    _hover_id += 1
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null


func _on_heal_zone_mouse_entered() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null

    _hover_id += 1
    var my_id := _hover_id

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    var tooltip = TooltipScene.instantiate()
    Global.add_tooltip(tooltip, self)
    var tooltip_panel = tooltip.get_node("Tooltip")
    _set_rest_tooltip_content(tooltip_panel)

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

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    var tooltip = TooltipScene.instantiate()
    Global.add_tooltip(tooltip, self)
    var tooltip_panel = tooltip.get_node("Tooltip")
    _set_rest_tooltip_content(tooltip_panel)

    var pos = get_global_mouse_position() + Vector2(24, 24)
    pos = pos.round()
    tooltip_panel.show_tooltip(pos)
    tooltip_instance = tooltip

func _on_heal_button_mouse_exited() -> void:
    _hover_id += 1
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
