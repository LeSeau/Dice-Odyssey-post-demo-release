class_name BerserkStatus
extends Status

var dmg_modifier_value: ModifierValue = null

func initialize_status(target: Node) -> void:
    Events.active_dice_changed.connect(_on_active_dice_changed.bind(target))
    _on_active_dice_changed(Global.dice_type, target)

func _on_active_dice_changed(active_dice, target: Node) -> void:
    var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
    
    if not dmg_modifier_value:
        dmg_modifier_value = ModifierValue.create_new_modifier("berserk", ModifierValue.Type.PERCENT_BASED)
    
    if active_dice == "red":
        dmg_modifier_value.percent_value = 0.5
    else:
        dmg_modifier_value.percent_value = 0.0
    
    dmg_dealt_modifier.add_new_value(dmg_modifier_value)
