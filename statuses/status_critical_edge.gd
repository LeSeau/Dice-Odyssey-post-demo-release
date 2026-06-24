class_name CriticalEdgeStatus
extends Status

const MAX_ROLL_BY_TYPE := {
    "blue": 6, "red": 6, "magma": 6, "mech": 6, "evil": 6,
    "giant": 12, "even": 8, "odd": 7, "green": 3,
}

func initialize_status(_target: Node) -> void:
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func _on_dice_rolled(dice_type: String, _roll_value) -> void:
    var max_roll = MAX_ROLL_BY_TYPE.get(dice_type, 6)
    if Global.last_roll == max_roll:
        var enemies = Global.player.get_tree().get_nodes_in_group("enemies")
        if not enemies.is_empty():
            var target_enemy = enemies[randi() % enemies.size()]
            var damage_effect := DamageEffect.new()
            damage_effect.amount = 5
            damage_effect.execute([target_enemy])

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
