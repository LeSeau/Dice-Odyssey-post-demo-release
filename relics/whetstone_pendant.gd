extends Relic

# The plain stat stick every pool needs - no condition, no timing, no build required. Its
# job is to be the safe pick that is never dead, which is what makes the conditional relics
# around it feel like decisions.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")
const STRENGTH := 2


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = STRENGTH
    status_effect.status = muscle
    status_effect.execute([player])
