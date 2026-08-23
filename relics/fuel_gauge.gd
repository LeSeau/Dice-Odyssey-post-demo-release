extends Relic

# Completes the Refuel trio: Flywheel pays a Scout card, Fuel-o-meter pays Strength on a big
# refuel, this one pays armour on every one. Refuelling is the "my turn went wrong" button,
# and this makes taking it cost you a little less.

const BLOCK_AMOUNT := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.refuel_happened.connect(_on_refuel_happened.bind(owner))


func _on_refuel_happened(_amount, owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var block_effect := BlockEffect.new()
    block_effect.amount = BLOCK_AMOUNT
    block_effect.execute([player])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.refuel_happened.is_connected(_on_refuel_happened):
        Events.refuel_happened.disconnect(_on_refuel_happened)
