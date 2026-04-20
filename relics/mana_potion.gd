extends Relic


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    if Global.tutorial_on == false:
        Global.blue_dice_bonus_amount+=1
        print("more dice")
    
