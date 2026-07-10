extends Card

const COUNTERWEIGHT_STATUS = preload("res://statuses/status_counterweight.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 8 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var counterweight := COUNTERWEIGHT_STATUS.duplicate()
        status_effect.status = counterweight
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.card_type_played.emit("exact")
    Events.reset_charged_card.emit()
