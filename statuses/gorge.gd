class_name GorgeStatus
extends Status

# The Famished: it grows every turn you end with an empty Dice pool.
#
# The amount travels in `stacks` (payload, stack_type NONE) like RationedStatus, so a future
# weaker or stronger version is a .tres edit rather than a second script.
#
# Hooked on player_turn_ended, which fires BEFORE player_handler.end_turn() spends anything
# else, so the pool read here is exactly what the player chose to leave behind.

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

var enemy_owner: Enemy = null


func initialize_status(_target: Node) -> void:
    enemy_owner = _target as Enemy
    tooltip = "Gains %d Strength each turn you end with no Dice left." % stacks
    if not Events.player_turn_ended.is_connected(_on_player_turn_ended):
        Events.player_turn_ended.connect(_on_player_turn_ended)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _on_player_turn_ended() -> void:
    # A dead owner must not keep eating: enemies leave the group the moment they die, but the
    # status resource outlives the badge for a frame or two.
    if enemy_owner == null or not is_instance_valid(enemy_owner):
        return
    if enemy_owner.stats == null or enemy_owner.stats.health <= 0:
        return
    if not Global.dice_pool_empty():
        return
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = stacks
    var status_effect := StatusEffect.new()
    status_effect.status = muscle
    status_effect.execute([enemy_owner])
    Events.enemy_strength_changed.emit()
