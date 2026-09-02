class_name DiceHostageStatus
extends Status

# The Dice Mimic's signature: it swallows one of your dice and withholds it from every refill
# until the mimic dies, at which point it coughs it back up immediately - usable that same turn.
#
# The die itself is tracked in Global.dice_hostage_types (one entry per stolen die), which
# dice_interface._on_player_turn_started() subtracts inline. See the comment on that array for
# why this is NOT built on <type>_dice_bonus_amount like the Dicelord's one-turn theft.
#
# This status owns the whole lifecycle - it appends its entry on init and erases it on return -
# so the badge on screen and the missing die can never disagree.
#
# 2026-09-02: the half-health ransom is GONE. It fired on the same turn most players could
# already burst the mimic down, so half the time the theft never happened at all and the rest
# of the time the die came back before it had cost anything. Death is the only release now,
# which is what makes the mimic's own HP the dial: it is squishy so that "kill it and get your
# die back into the fight" is a real turn-2 play, with a live fight-mate still standing.

var stolen_type: String = ""
var enemy_owner: Enemy = null
var returned := false


func initialize_status(_target: Node) -> void:
    enemy_owner = _target as Enemy
    if enemy_owner == null or stolen_type == "":
        return

    Global.dice_hostage_types.append(stolen_type)
    # Bite now, not next turn: the die goes missing on the turn it is taken.
    var prop := stolen_type + "_dice_current_amount"
    Global.set(prop, maxi(0, int(Global.get(prop)) - 1))
    Events.dice_amount_changed.emit()

    tooltip = "Holding one of your %s Dice. Kill it to get the Dice back." % (
        KeywordColorizer.dice_display_name(stolen_type))

    if not Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.connect(_on_enemy_died)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _on_enemy_died(enemy: Enemy) -> void:
    if enemy == enemy_owner:
        _return_die()


func _return_die() -> void:
    if returned:
        return
    returned = true

    Global.dice_hostage_types.erase(stolen_type)
    # Handed back usable THIS turn rather than at the next refill - the immediacy is the
    # reward beat for breaking it.
    var prop := stolen_type + "_dice_current_amount"
    Global.set(prop, int(Global.get(prop)) + 1)
    Events.dice_amount_changed.emit()

    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)

    # Retire the badge. StatusUI._on_status_changed frees itself once a status can expire and
    # has no duration left, and set_duration emits status_changed - so can_expire must be set
    # first or the badge would sit there forever.
    can_expire = true
    duration = 0
