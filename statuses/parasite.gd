class_name ParasiteStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

# This threshold is the tuning dial for how greedy the player is allowed to be. It went
# 15 -> 18 when Oculus became a long-lived scaler (44 HP), on the theory that bigger turns
# would be needed to kill it and 18 would keep "slow and safe vs fast and punished" a real
# choice - but in play 18 sat above what a normal turn reaches, so the punish almost never
# fired and the decision evaporated the other way. Back to 15 (Julien, 2026-07-28).
# The status tooltip reads this constant directly (status_tooltip.gd), so it follows.
const PARASITE_THRESHOLD := 15
const PARASITE_STRENGTH := 2

var target: Node
var triggered_this_turn := false

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    # Power gained WITHOUT rolling (Reinforce, Blaze, mech +1, ...) has to arm the punish too
    # - the tooltip has always promised "generate more than N Power in a turn", but before
    # 2026-08-29 only rolls were watched, so a big Reinforce turn walked past Oculus for free
    # (Julien). dice.gd credits power_generated_this_turn from this same signal; it connects
    # in its _ready(), which runs when the battle scene is instantiated, i.e. strictly before
    # start_battle() initializes enemy statuses - so its handler is always ahead of this one
    # and the total is already up to date here. The dice_rolled hook above stays as the
    # belt-and-braces: even if that ordering ever changed, the next roll re-checks.
    if not Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.connect(_on_change_current_power)
    if not Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.connect(_on_player_turn_started)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    _evaluate()


func _on_change_current_power() -> void:
    _evaluate()


# Single body for both hooks. change_current_power fires often (including refresh-only emits
# that change nothing), so the badge only re-emits when the number it shows actually moved.
func _evaluate() -> void:
    if not is_instance_valid(target):
        return
    var generated: int = Global.power_generated_this_turn
    if not triggered_this_turn and generated > PARASITE_THRESHOLD:
        triggered_this_turn = true
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = PARASITE_STRENGTH
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([target])
        Events.enemy_strength_changed.emit()
    if stacks != generated:
        stacks = generated
        status_changed.emit()

func _on_player_turn_started() -> void:
    triggered_this_turn = false
    stacks = Global.power_generated_this_turn
    status_changed.emit()
