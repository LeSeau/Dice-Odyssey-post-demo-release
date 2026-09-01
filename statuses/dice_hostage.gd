class_name DiceHostageStatus
extends Status

# The Dice Mimic's signature: it swallows one of your dice and withholds it from every refill
# until you beat it down to half health, at which point it coughs it back up immediately.
#
# The die itself is tracked in Global.dice_hostage_types (one entry per stolen die), which
# dice_interface._on_player_turn_started() subtracts inline. See the comment on that array for
# why this is NOT built on <type>_dice_bonus_amount like the Dicelord's one-turn theft.
#
# This status owns the whole lifecycle - it appends its entry on init and erases it on return -
# so the badge on screen and the missing die can never disagree.

# Fraction of max health at or below which the die comes back.
const RANSOM_FRACTION := 0.5

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

    tooltip = "Holding one of your %s Dice. Returns it at %d HP or less." % [
        KeywordColorizer.dice_display_name(stolen_type), ransom_hp()]

    # stats_changed fires on every health write (Stats.set_health), so this catches the
    # crossing wherever it happens - including a killing blow, because Stats.take_damage
    # writes health once before anything downstream notices the enemy is dead. Block writes
    # fire it too; _check_ransom is idempotent, so that is harmless.
    if not enemy_owner.stats.stats_changed.is_connected(_check_ransom):
        enemy_owner.stats.stats_changed.connect(_check_ransom)
    if not Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.connect(_on_enemy_died)

    _check_ransom()


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func ransom_hp() -> int:
    if enemy_owner == null:
        return 0
    return int(floor(enemy_owner.stats.max_health * RANSOM_FRACTION))


# True when the mimic is already at or below the ransom line, i.e. there is no point stealing
# because the die would come straight back. The steal action asks before taking anything.
static func is_below_ransom(enemy: Enemy) -> bool:
    if enemy == null or enemy.stats == null:
        return false
    return enemy.stats.health <= int(floor(enemy.stats.max_health * RANSOM_FRACTION))


func _check_ransom() -> void:
    if returned or enemy_owner == null or not is_instance_valid(enemy_owner):
        return
    if enemy_owner.stats.health > ransom_hp():
        return
    _return_die()


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

    if enemy_owner != null and is_instance_valid(enemy_owner)             and enemy_owner.stats.stats_changed.is_connected(_check_ransom):
        enemy_owner.stats.stats_changed.disconnect(_check_ransom)
    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)

    # Retire the badge. StatusUI._on_status_changed frees itself once a status can expire and
    # has no duration left, and set_duration emits status_changed - so can_expire must be set
    # first or the badge would sit there forever.
    can_expire = true
    duration = 0
