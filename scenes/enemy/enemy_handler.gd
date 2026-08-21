class_name EnemyHandler
extends Node2D

var acting_enemies: Array[Enemy] = []

func _ready() -> void:
    Events.enemy_died.connect(_on_enemy_died)
    Events.enemy_action_completed.connect(_on_enemy_action_completed)
    Events.player_hand_drawn.connect(_on_player_hand_drawn)


func setup_enemies(battle_stats: BattleStats) -> void:
    if not battle_stats:
        return
        
    for enemy: Enemy in get_children():
        enemy.queue_free()
        
    var all_new_enemies := battle_stats.enemies.instantiate()
    
    for new_enemy: Node2D in all_new_enemies.get_children():
        var new_enemy_child := new_enemy.duplicate() as Enemy 
        add_child(new_enemy_child)
        new_enemy_child.status_handler.statuses_applied.connect(_on_enemy_statuses_applied.bind(new_enemy_child))
    
    all_new_enemies.queue_free()

func reset_enemy_actions() -> void:
    for child in get_children():
        if child is Enemy:
            child.current_action = null
            child.update_action()


func start_turn() -> void:
    if get_child_count() == 0:
        print("no enemy children found: BUG?")
        return

    acting_enemies.clear()
    for child in get_children():
        if child is Enemy and _is_live(child):
            acting_enemies.append(child)
            
    _start_next_enemy_turn()



# A body is only a valid actor while it is still in the "enemies" group. _play_death_sequence()
# leaves that group the INSTANT the enemy dies, but the node stays a child of this handler for
# the full ~1.3s death animation before queue_free() lands - so get_children() keeps returning
# corpses, and membership of the group is the only thing that tells them apart. Same family as
# the act-2 Muscle off-by-one, where counting children during a deferred free was off by one;
# the death animation just widened that window from one frame to 1.3 seconds.
# The parameter is deliberately UNTYPED. Annotating it `Node` makes the call itself fail when
# the argument is an already-freed object - GDScript rejects the freed reference at the
# parameter boundary, before the body runs - so a typed guard aborts in precisely the case it
# exists to handle. Caught by debug_dead_enemy_turn.gd; gdtoolkit and a code read both pass it.
func _is_live(enemy) -> bool:
    return (is_instance_valid(enemy)
            and not enemy.is_queued_for_deletion()
            and enemy.is_in_group("enemies"))


func _start_next_enemy_turn() -> void:
    # Drop anything that died since the queue was built. Without this, acting_enemies[0] can be
    # a corpse: still a node (it takes a turn and attacks from beyond the grave) or already
    # freed, which crashes with "Invalid access to property 'status_handler' on previously
    # freed". An enemy can also die DURING the enemy turn - a start-of-turn status, a thrown
    # die landing late - so this has to be re-checked here, not only in start_turn().
    while not acting_enemies.is_empty() and not _is_live(acting_enemies[0]):
        acting_enemies.remove_at(0)

    if acting_enemies.is_empty():
        Events.enemy_turn_ended.emit()
        return
        
    acting_enemies[0].status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)

func _on_enemy_statuses_applied(type: Status.Type, enemy: Enemy) -> void:
    match type:
        Status.Type.START_OF_TURN:
            enemy.do_turn()
        Status.Type.END_OF_TURN:
            acting_enemies.erase(enemy)
            _start_next_enemy_turn()


func _on_enemy_died(enemy: Enemy) -> void:
    # erase() matches by reference, so it only removes THIS body; any other corpse still in the
    # queue is pruned by _start_next_enemy_turn().
    var is_enemy_turn := acting_enemies.size() > 0
    acting_enemies.erase(enemy)
    
    if is_enemy_turn:
        _start_next_enemy_turn()

func _on_enemy_action_completed(enemy: Enemy) -> void:
    enemy.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)

func _on_player_hand_drawn() -> void:
    for child in get_children():
        if child is Enemy:
            child.update_intent()
