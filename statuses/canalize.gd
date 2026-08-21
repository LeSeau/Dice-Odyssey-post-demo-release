class_name CanalizeStatus
extends Status
const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

# The tuning dial for how hard Dragonpriest punishes banking.
# History: 3 Strength above 9, dropped to 2 in the 2026-07-28 retune, now 3 above 12 (Julien,
# 2026-07-30) - the punish bites harder again, but only for genuinely greedy turns, so
# "spend in small packets" stays a real out rather than a tax on every ordinary turn.
# The status tooltip (status_tooltip.gd) interpolates these two constants directly, which is
# why that line can't drift out of date the way it did after the 07-28 change.
# (Replaces a `stacks_per_turn` var that nothing ever read - the amount was hardcoded below.)
const CANALIZE_THRESHOLD := 12
const CANALIZE_STRENGTH := 3

var target: Node
var threshold_triggered := false

func initialize_status(_target: Node) -> void:
    if not Events.check_canalize_status.is_connected(consume_stack):
        Events.check_canalize_status.connect(consume_stack)
    if not Events.change_current_power.is_connected(consume_stack):
        Events.change_current_power.connect(consume_stack)
    target = _target

func apply_status(target: Node) -> void:
    status_applied.emit(self)

func consume_stack() -> void:
    if target:
        if Global.roll_value > CANALIZE_THRESHOLD and not threshold_triggered:
            threshold_triggered = true
            var status_effect := StatusEffect.new()
            var muscle := MUSCLE_STATUS.duplicate()
            muscle.stacks = CANALIZE_STRENGTH
            status_effect.status = muscle
            status_effect.execute([target])
            status_applied.emit(self)
            status_changed.emit()
            Events.enemy_strength_changed.emit()
        elif Global.roll_value <= CANALIZE_THRESHOLD:
            threshold_triggered = false
