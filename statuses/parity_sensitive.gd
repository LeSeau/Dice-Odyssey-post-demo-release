class_name ParitySensitiveStatus
extends Status

# One half of the Parity Brothers. This is a VULNERABILITY WINDOW, never a feed and never a
# resistance (Julien, 2026-09-08: "odd / even-sensitive, meaning they take 50% more damage
# from damage inflicted from an odd / even power number"). The Odd Brother is soft while the
# player's banked Power is ODD, the Even Brother while it is EVEN.
#
# Exactly one brother is soft at any moment, so the fight is a routing puzzle rather than a
# race: Mech's +/-1 is a parity flipper, Ricochet (1/3/5/7) lands odd, Golem (2/4/6/8) lands
# even, and Blue alternates. That is the encounter - which brother you can hurt was decided
# in the dice shop, and which one you hurt THIS turn is decided by how you build the number.
#
# ⚠⚠ WHY READING Global.roll_value AT DAMAGE TIME IS CORRECT. Every damage card in the pool
# calls damage_effect.execute(targets) and only THEN emits Events.dice_roll_reset, on the next
# line (verified on warrior_axe_attack.gd and bullseye.gd, and it is the house shape). So the
# Power that produced the hit is still banked when Enemy.take_damage() reads DMG_TAKEN. A
# future card that reset BEFORE dealing its damage would read here as Power 0, which is even.
#
# ⚠ The cached percent is refreshed from the SAME signal set that keeps the on-screen Power
# number correct, so the badge can never disagree with the number the player is reading. Godot
# signals are synchronous, so a card that changes Power and then deals damage inside one
# apply_effects() still updates this modifier first.
#
# The bonus rides on `stacks` as a PERCENTAGE (stack_type NONE = payload, no badge number), so
# 50 means +50% and the dial is a .tres edit - same shape as GorgeStatus and RationedStatus.

const ODD_ID := "odd_sensitive"
const DEFAULT_PERCENT := 50

var enemy_owner: Enemy = null
var _wants_odd := true
var _modifier: Modifier = null


func initialize_status(target: Node) -> void:
    enemy_owner = target as Enemy
    _wants_odd = id == ODD_ID

    assert(target.get("modifier_handler"), "No modifiers on %s" % target)
    _modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
    assert(_modifier, "No dmg taken modifier on %s" % target)

    var value := _modifier.get_value(id)
    if not value:
        value = ModifierValue.create_new_modifier(id, ModifierValue.Type.PERCENT_BASED)
        value.percent_value = 0.0
        _modifier.add_new_value(value)

    # The Power-mutating set. dice_rolled/red_dice_rolled cover rolling, change_current_power
    # covers card-driven gains, dice_roll_reset and active_dice_changed cover the two ways it
    # drops to 0, player_turn_started covers the turn boundary and Stockpile carryover.
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    if not Events.red_dice_rolled.is_connected(_refresh):
        Events.red_dice_rolled.connect(_refresh)
    if not Events.change_current_power.is_connected(_refresh):
        Events.change_current_power.connect(_refresh)
    if not Events.dice_roll_reset.is_connected(_refresh):
        Events.dice_roll_reset.connect(_refresh)
    if not Events.active_dice_changed.is_connected(_on_active_dice_changed):
        Events.active_dice_changed.connect(_on_active_dice_changed)
    if not Events.player_turn_started.is_connected(_refresh):
        Events.player_turn_started.connect(_refresh)

    _refresh()


func apply_status(_target: Node) -> void:
    _refresh()


func is_vulnerable_now() -> bool:
    var power: int = Global.roll_value
    var power_is_odd: bool = int(abs(power)) % 2 == 1
    return power_is_odd == _wants_odd


func _percent() -> float:
    var pct: int = stacks if stacks > 0 else DEFAULT_PERCENT
    return float(pct) / 100.0


# ⚠ 2-arg signal, so it cannot bind straight to _refresh() - connecting a 0-arg callable to an
# N-arg signal is accepted at connect time and then never fires (documented project trap).
func _on_dice_rolled(_active_dice, _roll_value) -> void:
    _refresh()


func _on_active_dice_changed(_active_dice) -> void:
    _refresh()


func _refresh() -> void:
    if enemy_owner == null or not is_instance_valid(enemy_owner):
        _disconnect_all()
        return
    if _modifier == null or not is_instance_valid(_modifier):
        return
    var value := _modifier.get_value(id)
    if not value:
        return
    value.percent_value = _percent() if is_vulnerable_now() else 0.0


func _disconnect_all() -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.red_dice_rolled.is_connected(_refresh):
        Events.red_dice_rolled.disconnect(_refresh)
    if Events.change_current_power.is_connected(_refresh):
        Events.change_current_power.disconnect(_refresh)
    if Events.dice_roll_reset.is_connected(_refresh):
        Events.dice_roll_reset.disconnect(_refresh)
    if Events.active_dice_changed.is_connected(_on_active_dice_changed):
        Events.active_dice_changed.disconnect(_on_active_dice_changed)
    if Events.player_turn_started.is_connected(_refresh):
        Events.player_turn_started.disconnect(_refresh)
