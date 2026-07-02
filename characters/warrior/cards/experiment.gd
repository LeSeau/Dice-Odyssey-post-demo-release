extends Card

# Pool dédié aux cartes support générées
var support_pool: CardPile = preload("res://characters/warrior/warrior_draftable_support_cards.tres") as CardPile


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:

    # ------------------------
    # Deal damage
    # ------------------------
    var damage_effect := DamageEffect.new()
    var base_damage: int = Global.roll_value

    damage_effect.amount = modifiers.get_modified_value(
        base_damage,
        Modifier.Type.DMG_DEALT
    )

    damage_effect.sound = sound
    damage_effect.execute(targets)


    # ------------------------
    # Generate random support card
    # ------------------------
    var support_card: Card = get_random_support_card()

    if support_card != null:
        Events.add_card_to_hand_requested.emit(support_card)


    # ------------------------
    # Reset dice state
    # ------------------------
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()



func get_random_support_card() -> Card:

    # Safety check
    if support_pool == null:
        push_error("Support pool is null")
        return null

    if support_pool.cards.is_empty():
        push_error("Support pool is empty")
        return null


    # Pick random support card
    var new_card: Card = support_pool.cards.pick_random().duplicate() as Card


    # Make it temporary
    new_card.exhausts = true


    return new_card

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage. Get a random Support Card"
    if not has_active_roll():
        return "Deal X damage. Get a random Support Card"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    return "Deal %d damage. Get a random Support Card" % total
