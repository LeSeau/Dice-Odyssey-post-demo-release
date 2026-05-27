extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    #Events.reset_charged_card.emit()
    #Events.dice_rolled.connect(_on_dice_rolled)
    #Events.dice_roll_reset.emit()
    #
    #var status_effect := StatusEffect.new()
    #var exposed := EXPOSED_STATUS.duplicate()
    #exposed.duration = exposed_duration
    #status_effect.status = exposed
    #status_effect.execute(targets)
    
    var status_effect := StatusEffect.new()
    var exposed := EXPOSED_STATUS.duplicate()
    exposed.duration = 2
    status_effect.status = exposed
    status_effect.execute(targets)
    Events.reset_charged_card.emit()    
