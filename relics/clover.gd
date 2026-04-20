extends Relic

const LUCKY_STATUS = preload("res://statuses/lucky.tres")

func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    var status_effect := StatusEffect.new()
    var lucky := LUCKY_STATUS.duplicate()
    lucky.duration = 1
    status_effect.status = lucky
    status_effect.execute([player])
    
