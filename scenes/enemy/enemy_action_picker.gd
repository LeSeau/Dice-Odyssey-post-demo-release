class_name EnemyActionPicker
extends Node

@export var enemy: Enemy: set = _set_enemy
@export var target: Node2D: set = _set_target

@onready var total_weight := 0

var can_block_next_turn = true

func _ready() -> void:
    target = get_tree().get_first_node_in_group("player")
    setup_chances()


func get_action() -> EnemyAction:
    print(Global.fight_turn)
    var action := get_first_conditional_action()
    if action:
        return action
        
    return get_chance_based_action()


func get_first_conditional_action() -> EnemyAction:
    for action: EnemyAction in get_children():
        if not action or action.type != EnemyAction.Type.CONDITIONAL:
            continue
            
        if action.is_performable():
            return action
    
    return null


func get_chance_based_action() -> EnemyAction:
    var roll := randf_range(0.0, total_weight)
    
    for action: EnemyAction in get_children():
        if not action or action.type != EnemyAction.Type.CHANCE_BASED:
            continue
        
        if action.accumulated_weight > roll:
            # Check restrictions
            if action.is_performable():
                return action
            # If this action is forbidden, we ignore it and continue searching
    # fallback — pick the first performable chance-based action
    for action: EnemyAction in get_children():
        if action.type == EnemyAction.Type.CHANCE_BASED and action.is_performable():
            return action
    
    # if absolutely nothing is valid, return something (avoid freezing)
    return get_child(0)



func setup_chances() -> void:
    for action: EnemyAction in get_children():
        if not action or action.type != EnemyAction.Type.CHANCE_BASED:
            continue
        
        total_weight += action.chance_weight
        action.accumulated_weight = total_weight


func _set_enemy(value: Enemy) -> void:
    enemy = value
    
    for action: EnemyAction in get_children():
        action.enemy = enemy
        action.modifiers = enemy.modifier_handler


func _set_target(value: Node2D) -> void:
    target = value
    
    for action: EnemyAction in get_children():
        action.target = target
