extends Relic

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # Thrown 1s count too (Julien, 2026-07-23) - Pixie Volley's d3s and Kickstart's odd die
    # are prime feeders. The landed value rides the signal because thrown dice never touch
    # Global.last_roll (they're outside the Power chain).
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))

func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1:
        return
    _grant_strength(owner)

func _on_dice_thrown_landed(_dice_type: String, value: int, owner: RelicUI) -> void:
    if value != 1:
        return
    _grant_strength(owner)

func _grant_strength(owner: RelicUI) -> void:
    owner.flash()
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 1
    status_effect.status = muscle
    status_effect.execute([player])

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
