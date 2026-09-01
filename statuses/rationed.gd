class_name RationedStatus
extends Status

# The Quartermaster: a hard ceiling on how many Dice you may ROLL in a turn.
#
# The cap travels in `stacks` with stack_type NONE - the payload-not-badge pattern used by
# Effigy and Dicelord Gift, which is how two .tres files can differ on a number while sharing
# one class_name. The badge shows no counter; the tooltip carries the number.
#
# It writes Global.dice_spend_cap, which dice.gd::_spend_cap_blocks_roll reads. Fight-scoped
# there (battle.gd::start_battle zeroes it), so the cap can never leak into the next fight
# even if this enemy dies with the status still on it.

var enemy_owner: Enemy = null


func initialize_status(_target: Node) -> void:
    enemy_owner = _target as Enemy
    Global.dice_spend_cap = stacks
    tooltip = "You may roll at most %d Dice per turn." % stacks
    # Lifting the cap the moment it dies is the reward for killing it - without this the
    # restriction would outlive the enemy that imposes it for the rest of the fight.
    if not Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.connect(_on_enemy_died)


func apply_status(_target: Node) -> void:
    status_applied.emit(self)


func _on_enemy_died(enemy: Enemy) -> void:
    if enemy != enemy_owner:
        return
    Global.dice_spend_cap = 0
    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)
