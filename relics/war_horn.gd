extends Relic


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    var oracle_card = load("res://characters/warrior/cards/card_oracle_exhaust.tres")
    Events.add_card_to_hand_requested.emit(oracle_card)
    
