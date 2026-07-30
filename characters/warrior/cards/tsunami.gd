extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value + Global.fight_dice_rolled * 1
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Deal X damage, plus 1 for each Dice rolled this combat\n(%d Dice rolled this combat)" % Global.fight_dice_rolled
