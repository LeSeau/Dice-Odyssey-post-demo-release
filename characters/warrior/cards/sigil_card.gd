extends Card

const SIGIL_STATUS = preload("res://statuses/sigil.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value % 2 != 0:
        # Reuses the exact status the Sigil Slug applies to itself - the existing
        # reactive check (dice.gd::_check_sigil_trigger, "Global.roll_value == sigil.stacks
        # -> +1 Blue Dice") is enemy-agnostic and already fires for any enemy
        # carrying this status, regardless of source.
        var status_effect := StatusEffect.new()
        var sigil := SIGIL_STATUS.duplicate()
        status_effect.status = sigil
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
