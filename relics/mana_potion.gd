extends Relic


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    # Was gated off during the tutorial (kept the loadout at a "clean" 2 Blue + 1 Red) - now
    # left on deliberately: it's the same relic the player owns in every real fight
    # afterward, so having it silently absent here meant fight #2 sprang a 3rd Blue Dice on
    # them with zero explanation. The tutorial now explains it directly instead (see
    # TutorialDirector's _step_t1_relic).
    Global.blue_dice_bonus_amount+=1
    print("more dice")
    
