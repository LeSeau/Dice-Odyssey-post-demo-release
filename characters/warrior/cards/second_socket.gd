extends Card

# "Your Red Dice gains a second card socket. One roll plays both."
# Raises Global.red_socket_capacity; dice.gd fills socket 2 instead of evicting socket 1, and
# the roll plays every id in Global.charged_card_instance_ids in socket order.
#
# The whole feature is additive on purpose: at capacity 1 nothing about the socket behaves
# differently, because the Red socket lifecycle is the most bug-prone part of the game.

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.red_socket_capacity = maxi(Global.red_socket_capacity, 2)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = preload("res://statuses/status_second_socket.tres").duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
