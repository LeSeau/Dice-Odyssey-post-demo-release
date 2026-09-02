extends EnemyAction

const HOSTAGE_STATUS = preload("res://statuses/dice_hostage.tres")

# Every type the mimic can swallow. It only picks among types the player actually OWNS
# (<type>_dice_max_amount > 0), so a loadout that never bought Magma can never have Magma
# taken. Mirrors dicelord_dice_theft.gd's STEALABLE_TYPES.
const STEALABLE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

@export var damage := 3
var base_damage = damage


# Beat 0 of the mimic's fixed cycle: bite, and swallow one of your dice.
func is_performable() -> bool:
    return Global.fight_turn == 0


func perform_action() -> void:
    if not enemy or not target:
        return

    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound

    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_callback(_steal_die)
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)

    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


func _steal_die() -> void:
    if not is_instance_valid(enemy):
        return

    var owned: Array[String] = []
    for type: String in STEALABLE_TYPES:
        if int(Global.get(type + "_dice_max_amount")) > 0:
            owned.append(type)
    if owned.is_empty():
        return

    var hostage: DiceHostageStatus = HOSTAGE_STATUS.duplicate()
    # Set on the duplicate rather than relying on duplicate() to carry it: stolen_type is a
    # plain script var, not an @export, so it has no STORAGE usage flag to be copied.
    hostage.stolen_type = owned[randi() % owned.size()]
    var status_effect := StatusEffect.new()
    status_effect.status = hostage
    status_effect.execute([enemy])


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
