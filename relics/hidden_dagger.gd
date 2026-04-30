extends Relic


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    Global.next_roll_modifier+=3
    Events.display_next_roll_modifier.emit()
    
    
