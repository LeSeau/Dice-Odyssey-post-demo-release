extends Status

# Artillery blessing: each turn, hurl one die of a random type at a random enemy.
# START_OF_TURN, so StatusHandler drives it - no signal wiring and nothing to disconnect.
#
# Uses the same Events.dice_thrown -> Card._land_thrown_die plumbing every throw card uses, so
# it inherits the flight visual, the volley timing, Trebuchet's bonus and the "a thrown die
# counts as rolled" reporting for free.

const CARD := preload("res://characters/warrior/cards/card_artillery.tres")


func apply_status(target: Node) -> void:
    status_applied.emit(self)
    if target == null or not is_instance_valid(target):
        return
    var tree := target.get_tree()
    if tree == null:
        return
    var enemies := tree.get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    # ANY of the nine types, owned or not (Julien, 2026-08-20). The blessing is a bombardment
    # from somewhere else, not a second draw from your own bag - which is also what makes it
    # worth a card in a two-type starter deck, where "one you own" meant Blue or Red.
    var pool: Array = Global.DICE_TYPE_ORDER
    if pool.is_empty():
        return
    var dice_type: String = pool[randi() % pool.size()]
    var faces: Array = Card.thrown_faces_for(dice_type)
    var value: int = faces[randi() % faces.size()]
    var enemy: Node = enemies[randi() % enemies.size()]
    Events.dice_thrown.emit([{"type": dice_type, "value": value, "target": enemy}],
            enemy.global_position)
    # Reuses the shared landing helper so the damage lands with the flight visual and picks up
    # Trebuchet's per-throw bonus, exactly like a thrown die from a card.
    CARD._land_thrown_die(tree, enemy, value, Global.DICE_THROW_FLIGHT_TIME, CARD.sound, dice_type, value)
