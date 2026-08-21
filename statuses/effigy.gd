class_name EffigyStatus
extends Status

# Effigy's curse: for the rest of the FIGHT, every natural 6 the player rolls hits this enemy
# for its per-six damage. The sixes payoff aimed at a single target (Jackpot is the whole-fight
# lump); buying an Evil die - 75% sixes - is what turns this into a machine gun.
#
# Keyed on Global.last_roll, the face actually rolled, so a Boosted or Loaded 5->6 never
# counts - the same ruling Arcane and Critical Edge already follow. dice_rolled carries the
# ACCUMULATED power, not the face, which is exactly why it can't be used for the check.

# Damage per six rides on `stacks` rather than a const so the base status (5) and
# effigy_plus.tres (8) can share this script - the same trick Trebuchet+ uses. stack_type is
# NONE on both resources, so the number is a payload, not a badge. DEFAULT_DAMAGE is only a
# floor for a resource that somehow arrives with stacks unset.
const DEFAULT_DAMAGE := 5

var target: Node
var _last_roll_token := -1


func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    # dice.gd emits red_dice_rolled INSTEAD of dice_rolled for the Red die - without this a
    # Red 6 would silently not count.
    if not Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.connect(_on_red_dice_rolled)
    if not Events.dice_thrown_landed.is_connected(_on_thrown_die_landed):
        Events.dice_thrown_landed.connect(_on_thrown_die_landed)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    if Global.last_roll == 6:
        _strike()


func _on_red_dice_rolled() -> void:
    if Global.last_roll == 6:
        _strike()


func _on_thrown_die_landed(_dice_type: String, value: int) -> void:
    if value == 6:
        _strike()


func _strike() -> void:
    if target == null or not is_instance_valid(target):
        _disconnect_all()
        return
    if not _consume_roll_token():
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = maxi(stacks, DEFAULT_DAMAGE)
    damage_effect.execute([target])


func _disconnect_all() -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_thrown_die_landed):
        Events.dice_thrown_landed.disconnect(_on_thrown_die_landed)


# ONE trigger per roll. dice.gd emits red_dice_rolled for a Red roll, and card_ui.gd:909 then
# re-emits dice_rolled right after the socketed card plays - so a single Red roll reaches us
# TWICE (Julien, 2026-08-16: "it triggers twice after I roll red"). Keyed on
# Global.fight_dice_rolled, which increments exactly once per real roll and once per thrown
# die landing, so every genuine die still counts exactly once.
func _consume_roll_token() -> bool:
    if Global.fight_dice_rolled == _last_roll_token:
        return false
    _last_roll_token = Global.fight_dice_rolled
    return true
