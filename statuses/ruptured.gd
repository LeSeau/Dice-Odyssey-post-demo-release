class_name RupturedStatus
extends Status

# Rupture's payload: for the REST OF THIS TURN, every Dice the player rolls also hits this
# enemy for DAMAGE_PER_ROLL. Inverts the game's normal sequencing - every other card wants to
# be played after you've banked, this one wants to be played at 0 Power and rolled INTO.
#
# Two signals, not one, and each is load-bearing:
#   dice_rolled     - normal rolls, but dice.gd does NOT emit it for the Red die
#   red_dice_rolled - ...which is why this is here too
# Thrown dice are NOT rolls and deliberately do not bleed this enemy (2026-08-29 ruling).
#
# Owner-bound like ParasiteStatus: the resource is duplicated per application, holds its own
# target, and every handler re-validates it because the enemy can die mid-turn.

const DAMAGE_PER_ROLL := 3

var target: Node
var _last_roll_token := -1


func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    if not Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.connect(_on_red_dice_rolled)
    if not Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.connect(_on_player_turn_started)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    _bleed()


func _on_red_dice_rolled() -> void:
    _bleed()


func _bleed() -> void:
    if duration <= 0 or target == null or not is_instance_valid(target):
        return
    if not _consume_roll_token():
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = DAMAGE_PER_ROLL
    damage_effect.execute([target])


# Turn-scoped. EVENT_BASED statuses are skipped by StatusHandler.apply_statuses_by_type, so
# nothing decrements duration for us - expiring is this status's own job. duration = 0 makes
# StatusUI free the badge (it needs can_expire = true in the .tres for that branch to fire).
func _on_player_turn_started() -> void:
    duration = 0
    _disconnect_all()


func _disconnect_all() -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)


# ONE trigger per roll. dice.gd emits red_dice_rolled for a Red roll, and card_ui.gd:909 then
# re-emits dice_rolled right after the socketed card plays - so a single Red roll reaches us
# TWICE (Julien, 2026-08-16: "it triggers twice after I roll red"). Keyed on
# Global.fight_dice_rolled, which increments exactly once per real roll (thrown dice do not
# touch it since 2026-08-29), so every genuine roll still counts exactly once.
func _consume_roll_token() -> bool:
    if Global.fight_dice_rolled == _last_roll_token:
        return false
    _last_roll_token = Global.fight_dice_rolled
    return true
