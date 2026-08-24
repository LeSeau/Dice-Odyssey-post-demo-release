extends Relic

# Draws instead of handing out a Scout 2 card (Julien, 2026-08-24), and drops to Common.
# Same reasoning as Runic Bones: card draw is the thinnest ladder in the pool, and a refuel
# already means the turn went wrong, so refilling the hand is the help you actually want at
# that moment. It also stops the relic from stuffing the hand with Scout cards you then have
# to spend turns playing.


func initialize_relic(owner: RelicUI) -> void:
    Events.refuel_happened.connect(_on_refuel_happened.bind(owner))


func _on_refuel_happened(_amount, owner: RelicUI) -> void:
    owner.flash()
    Events.draw_card.emit(2)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.refuel_happened.is_connected(_on_refuel_happened):
        Events.refuel_happened.disconnect(_on_refuel_happened)
