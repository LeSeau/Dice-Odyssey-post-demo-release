class_name BrothersRageStatus
extends Status

# The survivor's payoff: when the OTHER brother dies, this one gains Strength once.
#
# ⚠ Deliberately NOT an HP threshold. Julien cut the Lava Hound's <=50% beat twice (08-29 and
# 09-06), so act 1 still has no HP-threshold beat and this must not quietly become the first
# one. Hanging it on the brother's death is also what turns kill order into the decision: the
# twin you leave standing is the one you have chosen to enrage, and by then you already know
# which of them your dice have been feeding all fight.
#
# Amount rides on `stacks` (payload, stack_type NONE) so the dial is a .tres edit.
#
# The trigger is "any OTHER enemy in this fight died", which in a two-body encounter is
# exactly "my brother". Kept general rather than matching on a name so the status stays
# reusable, and so renaming a body can never silently disarm it.

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")
const DEFAULT_STRENGTH := 3

var enemy_owner: Enemy = null
var _spent := false


func initialize_status(_target: Node) -> void:
    enemy_owner = _target as Enemy
    tooltip = "Gains %d Strength when his brother dies." % _strength()
    if not Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.connect(_on_enemy_died)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _strength() -> int:
    return stacks if stacks > 0 else DEFAULT_STRENGTH


func _on_enemy_died(dead: Enemy) -> void:
    if _spent:
        return
    if enemy_owner == null or not is_instance_valid(enemy_owner):
        _disconnect()
        return
    # Own death fires this signal too; raging at your own funeral is not the beat.
    if dead == enemy_owner:
        _disconnect()
        return
    if enemy_owner.stats == null or enemy_owner.stats.health <= 0:
        return
    _spent = true
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = _strength()
    var status_effect := StatusEffect.new()
    status_effect.status = muscle
    status_effect.execute([enemy_owner])
    Events.enemy_strength_changed.emit()
    _disconnect()


func _disconnect() -> void:
    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)
