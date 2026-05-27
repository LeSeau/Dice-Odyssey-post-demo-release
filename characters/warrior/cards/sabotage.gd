extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var base_damage := 4
var exposed_duration := 2
var weak_duration := 2

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value <= 2:
        Events.dice_rolled.connect(_on_dice_rolled)

        var status_effect := StatusEffect.new()
        var exposed := EXPOSED_STATUS.duplicate()
        exposed.duration = exposed_duration
        status_effect.status = exposed
        status_effect.execute(targets)
        
        if Global.roll_value % 2 == 1:
            var damage_effect := DamageEffect.new()
            var base_damage = 3
            damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT) 
            damage_effect.sound = sound
            damage_effect.execute(targets)
            
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()
func _on_dice_rolled():
    print("adding dice to damage")
