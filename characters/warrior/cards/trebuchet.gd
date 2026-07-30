extends Card

const TREBUCHET_STATUS = preload("res://statuses/status_trebuchet.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    # Blessing gate (Min 6) - Prayer Beads bypasses it like every other Blessing.
    if meets_requirement():
        # The real effect lives in this fight-scoped Global (reset by battle.gd::start_battle);
        # the status is the visible badge, same split as Emanation.
        Global.thrown_dice_bonus_fight += 2
        var status_effect := StatusEffect.new()
        var trebuchet := TREBUCHET_STATUS.duplicate()
        status_effect.status = trebuchet
        status_effect.sound = sound
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
