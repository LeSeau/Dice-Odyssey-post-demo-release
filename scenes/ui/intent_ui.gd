class_name IntentUI
extends HBoxContainer

const TooltipScene = preload("res://scenes/ui/intent_tooltip.tscn")

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

var tooltip_instance = null

func update_intent(intent: Intent) -> void:
    if not intent:
        hide()
        return
    
    icon.texture = intent.icon
    icon.visible = icon.texture != null
    label.text = str(intent.current_text)
    label.visible = intent.current_text.length() > 0
    show()

func _get_tooltip_text_for_icon() -> String:
    if not icon.texture:
        return ""
    var icon_name = icon.texture.resource_path.get_file().get_basename().to_lower()
    match icon_name:
        "attack_icon_intent":
            return "This enemy will attack you."
        "shield":
            return "This enemy will block damage next turn."
        "debuff_icon_3":
            return "This enemy will inflict a negative effect to you."
        "debuff_icon":
            return "This enemy will inflict a negative effect to you."
        "debuff_intent":
            return "This enemy will inflict a negative effect to you."
        "buff_icon_intent":
            return "This enemy will gain a positive effect."
        "buff_icon":
            return "This enemy will gain a positive effect."
        "buff_block_intent":
            return "This enemy will gain a positive effect and block damage next turn."
        _:
            return "This enemy is preparing something."

func _on_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout
    if not get_global_rect().has_point(get_global_mouse_position()):
        return
    var text = _get_tooltip_text_for_icon()
    if text == "":
        return
    
    tooltip_instance = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance)
    var tooltip_panel = tooltip_instance.get_node("Tooltip")
    tooltip_panel.get_node("%TooltipText").text = text
    tooltip_panel.show_tooltip(global_position + Vector2(-40, -80))
    
    _start_tooltip_safety_timeout(tooltip_instance)

func _start_tooltip_safety_timeout(this_tooltip) -> void:
    await get_tree().create_timer(8.0).timeout
    # Only free it if it's still the active one and hasn't already been freed.
    if is_instance_valid(this_tooltip) and tooltip_instance == this_tooltip:
        this_tooltip.queue_free()
        tooltip_instance = null

func _on_mouse_exited() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
