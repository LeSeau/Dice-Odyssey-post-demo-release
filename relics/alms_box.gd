extends Relic

# Blessings cost you a whole turn of tempo to set up. This refunds part of that in armour, so
# the setup turn is not also the turn you take a full hit to the face.

const BLOCK_AMOUNT := 5


func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played.bind(owner))


func _on_card_played(card: Card, owner: RelicUI) -> void:
    if card.type != Card.Type.BLESSING:
        return
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var block_effect := BlockEffect.new()
    block_effect.amount = BLOCK_AMOUNT
    block_effect.execute([player])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.card_played.is_connected(_on_card_played):
        Events.card_played.disconnect(_on_card_played)
