extends Card

# IN-HAND PASSIVE: while held, your dice cannot roll their lowest face. Applied inside
# Global.current_face_values(), so the roll, the Scout preview and thrown dice all agree.
#
# Play effect is Lucky 1 rather than Julien's specced "reroll your last roll": the reroll
# machinery is Ricochet-specific (it restores a snapshot only captured for reroll-capable
# types), and driving it from a card would have meant reaching into dice.gd's internals.
# Lucky keeps the talisman-of-fortune read and is a mechanic that already exists. Flagged as a
# deviation - say the word and it can become a real reroll.

const LUCKY_STATUS = preload("res://statuses/lucky.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    var lucky := LUCKY_STATUS.duplicate()
    lucky.stacks = 1
    status_effect.status = lucky
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.reset_charged_card.emit()
