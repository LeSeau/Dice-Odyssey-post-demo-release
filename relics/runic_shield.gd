extends Relic


func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    owner.flash()
    var block_effect := BlockEffect.new()
    var remaining_dice_amount = Global.blue_dice_current_amount + Global.red_dice_current_amount + Global.giant_dice_current_amount + Global.magma_dice_current_amount + Global.green_dice_current_amount + Global.evil_dice_current_amount + Global.even_dice_current_amount + Global.odd_dice_current_amount + Global.mech_dice_current_amount
    block_effect.amount = remaining_dice_amount * 3
    block_effect.execute([player]) 
    
