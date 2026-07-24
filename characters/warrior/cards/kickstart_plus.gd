extends Card

# Kickstart+ throws TWO Pixie Dice (d3) instead of one - each grants ITS roll as Strength
# on landing, sequenced by the shared volley stagger, so the two grants sum to their total
# roll. Own script because the count lives in the throw. See kickstart.gd for design notes.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")
const THROW_COUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var player: Node = targets[0] if not targets.is_empty() else null
    var faces: Array = thrown_faces_for("green")
    var throws: Array = []
    var stagger := Global.dice_throw_volley_stagger(THROW_COUNT)
    for i in THROW_COUNT:
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": "green", "value": value, "target": null})
        if player != null:
            var timer := player.get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME + stagger * i, false)
            timer.timeout.connect(_on_kickstart_landed.bind(player, value))
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.reset_charged_card.emit()


func _on_kickstart_landed(player: Node, value: int) -> void:
    Global.report_thrown_die_landed("green", value)
    if player == null or not is_instance_valid(player) or value <= 0:
        return
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = value
    status_effect.status = muscle
    status_effect.execute([player])
