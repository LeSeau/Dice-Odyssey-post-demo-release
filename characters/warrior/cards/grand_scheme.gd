extends Card

# Net-positive Celestial rare for the information archetype: Charge 1 (active type) and
# gain a Scout 5 card in hand. SUPPORT flag: never resets your Power. Exhausts.
# load() is ResourceLoader-cached - duplicate before handing the Scout 5 out so two
# copies never share one Card object/instance_id (same guard as calculations.gd).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var prop := "%s_dice_current_amount" % Global.dice_type
    Global.set(prop, int(Global.get(prop)) + 1)
    Events.dice_charged.emit(Global.dice_type, 1)
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit(Global.dice_type)
    var scout_card = load("res://characters/warrior/cards/card_scout5.tres").duplicate()
    Events.add_card_to_hand_requested.emit(scout_card)
    Events.reset_charged_card.emit()
