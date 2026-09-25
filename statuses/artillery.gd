extends Status

# Artillery blessing: each turn, hurl one die of a random type at a random enemy.
# START_OF_TURN, so StatusHandler drives it - no signal wiring and nothing to disconnect.
#
# Uses the same Events.dice_thrown -> Card._land_thrown_die plumbing every throw card uses, so
# it inherits the flight visual, the volley timing and Trebuchet's bonus for free.
#
# Since 2026-08-29 these throws are NOT rolls: they no longer advance any roll counter. That
# also fixed a real bug - this blessing's start-of-turn die used to land as "die #1 of the
# turn", which silently ate Assault's first-roll bonus and pre-seeded the rainbow set.

# ⚠️ load() at call time, NOT preload(). This status and its card preload each other:
#   statuses/artillery.gd -> card_artillery.tres -> cards/artillery.gd -> statuses/artillery.tres
#   -> statuses/artillery.gd
# Godot breaks that cycle by dropping one side, and the side it dropped was the card's script -
# so card_artillery.tres loaded as a bare Resource and the CARD.sound below crashed the first
# time this blessing ticked. Resolving the card lazily removes the parse-time edge entirely;
# by the time a turn starts everything is long since loaded, so this costs nothing.
const CARD_PATH := "res://characters/warrior/cards/card_artillery.tres"


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
    # Reuses the shared landing helper so the damage lands with the flight visual and picks up
    # Trebuchet's per-throw bonus, exactly like a thrown die from a card.
    var card: Card = load(CARD_PATH)
    if card == null:
        return
    # One die per Artillery played (stacks = copies, see absorb_copy), staggered like a
    # Pixie Volley so each hit lands on its own die's slam.
    var count := maxi(stacks, 1)
    var stagger := Global.dice_throw_volley_stagger(count)
    var throws: Array = []
    for i in count:
        var dice_type: String = pool[randi() % pool.size()]
        var faces: Array = Card.thrown_faces_for(dice_type)
        var value: int = faces[randi() % faces.size()]
        var enemy: Node = enemies[randi() % enemies.size()]
        throws.append({"type": dice_type, "value": value, "target": enemy})
        card._land_thrown_die(tree, enemy, value, Global.DICE_THROW_FLIGHT_TIME + stagger * i,
                card.sound, dice_type, value)
    Events.dice_thrown.emit(throws, throws[0]["target"].global_position)


func absorb_copy(other: Status) -> bool:
    stacks += other.stacks
    return true


func get_tooltip() -> String:
    var count := maxi(stacks, 1)
    if count == 1:
        return tooltip
    return "At the start of each turn, throw %d Dice of random types at random enemies" % count
