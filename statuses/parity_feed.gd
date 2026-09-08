# ⚠⚠ ORPHANED 2026-09-08 - NOT REFERENCED BY ANY .tres, DO NOT POINT ONE AT IT.
# This was the FIRST, WRONG reading of the Parity Brothers: it made the player's odd/even
# FACES feed the brothers Strength. Julien's actual concept is the opposite direction -
# the brothers are odd/even SENSITIVE and take 50% more damage while the player's banked
# Power has their parity (a vulnerability window, never a resistance, never a feed).
# The live implementation is statuses/parity_sensitive.gd. Kept on disk only as history.

class_name ParityFeedStatus
extends Status

# One half of the Parity Brothers' clock. The Odd Brother eats every ODD face the player
# rolls, the Even Brother every EVEN one, +1 Strength each time. The fight deliberately has no
# ramp of its own - no per-turn creep, no guard that buffs - so the only thing that grows
# these two is the dice the player chose in the shop. That is the encounter (Slate E-1: "which
# brother you fatten was decided in the dice shop"): Blue feeds both evenly, Golem starves Odd
# and gorges Even, Ricochet does the reverse, and Mech's +/-1 is a parity flipper.
#
# Which parity this instance wants comes from `id`, so both brothers share one script and the
# two .tres differ by a single string. The Strength per face rides on `stacks` (payload,
# stack_type NONE) so the dial is a .tres edit, exactly like GorgeStatus and RationedStatus.
#
# ⚠ Keyed on Global.last_roll - the face actually rolled - and NOT on the value dice_rolled
# carries, which is the accumulated Power. Same ruling Arcane, Effigy and Critical Edge
# already follow: a 5 boosted to 6 stays an odd roll. The Evil die's 0 counts as EVEN, so an
# Evil deck (6/6/6/0) feeds the Even Brother on nearly every roll and is his natural prey.

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")
const ODD_ID := "parity_odd"
const DEFAULT_STRENGTH := 1

var enemy_owner: Enemy = null
var _wants_odd := true
var _last_roll_token := -1


func initialize_status(_target: Node) -> void:
    enemy_owner = _target as Enemy
    _wants_odd = id == ODD_ID
    var word := "odd" if _wants_odd else "even"
    tooltip = "Gains %d Strength for every %s face you roll." % [_strength(), word]
    # dice.gd emits red_dice_rolled INSTEAD of dice_rolled for a Red roll, so without the
    # second hook a Red face would silently never feed either brother.
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    if not Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.connect(_on_red_dice_rolled)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _strength() -> int:
    return stacks if stacks > 0 else DEFAULT_STRENGTH


func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    _feed()


func _on_red_dice_rolled() -> void:
    _feed()


func _feed() -> void:
    if enemy_owner == null or not is_instance_valid(enemy_owner):
        _disconnect_all()
        return
    # A dead brother must not keep eating. Enemies leave the `enemies` group the moment they
    # die but the status resource outlives the badge by a frame or two.
    if enemy_owner.stats == null or enemy_owner.stats.health <= 0:
        return
    var rolled_odd: bool = int(abs(Global.last_roll)) % 2 == 1
    if rolled_odd != _wants_odd:
        return
    if not _consume_roll_token():
        return
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = _strength()
    var status_effect := StatusEffect.new()
    status_effect.status = muscle
    status_effect.execute([enemy_owner])
    Events.enemy_strength_changed.emit()


func _disconnect_all() -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)


# ONE feed per roll. A single Red roll reaches us twice (dice.gd emits red_dice_rolled, then
# card_ui.gd re-emits dice_rolled once the socketed card resolves) - the same double-fire
# EffigyStatus and RupturedStatus already guard against. Global.fight_dice_rolled increments
# exactly once per real roll, and thrown dice have not touched it since 2026-08-29.
func _consume_roll_token() -> bool:
    if Global.fight_dice_rolled == _last_roll_token:
        return false
    _last_roll_token = Global.fight_dice_rolled
    return true
