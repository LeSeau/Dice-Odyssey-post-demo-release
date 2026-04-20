extends Relic

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the red dice rolled event when the relic is added
    Events.card_type_played.connect(_on_card_type_played)



func _on_card_type_played(card_type):
    print(card_type)
    Events.draw_card.emit(1)
