extends Card

# Single-target sixes payoff - point the doll, then roll. Everything lives in EffigyStatus
# (statuses/effigy.gd), which has to listen to three roll signals and survive this card
# leaving play. Deliberately does NOT reset Power: it's pure setup, and making it cost the
# bank would fight the "curse first, then roll big" pattern it exists to create.

const EFFIGY_STATUS = preload("res://statuses/effigy.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if targets.is_empty():
        return
    var status_effect := StatusEffect.new()
    status_effect.status = EFFIGY_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
