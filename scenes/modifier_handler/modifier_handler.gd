class_name ModifierHandler
extends Node


func has_modifier(type: Modifier.Type) -> bool:
    for modifier: Modifier in get_children():
        if modifier.type == type:
            return true
    return false

func get_modifier(type: Modifier.Type) -> Modifier:
    for modifier: Modifier in get_children():
        if modifier.type == type:
            return modifier
    return null
    
func get_modified_value(base: int, type: Modifier.Type) -> int:
    var value := base
    
    # IN-HAND PASSIVES (Dead Weight+): flat damage granted by a card merely being HELD.
    # Folded into `base` here rather than pushed as a ModifierValue because in-hand state has
    # no add/remove event to sync against - Global.in_hand() scans the live Hand, so reading
    # it at use time is the only way it cannot desync. Adding before delegating makes it
    # behave exactly like a Strength stack (summed with the other FLATs, then percent-scaled).
    # Player only: an enemy's handler must never see the player's hand.
    if type == Modifier.Type.DMG_DEALT and _is_player_handler():
        value += Global.in_hand_damage_bonus()
        # Worm's Eye Lens: flat bonus for cards gated on a MAX roll. Folded into `base` for
        # the same reason as the line above - it lands before the percent modifiers and the
        # dynamic descriptions get it for free, so the preview can never disagree with the
        # damage actually dealt. Global.playing_card_requirement is only set for the window
        # Card.play() opens, so relic/status damage reacting to the same roll is excluded.
        if Global.max_card_damage_bonus != 0 \
                and Global.playing_card_requirement == Card.Requirement.MAX:
            value += Global.max_card_damage_bonus

    var modifier := get_modifier(type)
    
    if not modifier:
        return value 
        
    return modifier.get_modified_value(value)


func _is_player_handler() -> bool:
    var parent := get_parent()
    return parent != null and parent.is_in_group("player")
