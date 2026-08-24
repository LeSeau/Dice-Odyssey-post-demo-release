extends Relic

# Capped at once per turn (Julien, 2026-08-24). Uncapped it ran away on any die with a small
# face set - a d3 Pixie repeats about a third of the time, so a swarm turn could hand back
# most of the dice it spent and the relic paid for itself several times over in one turn.
#
# The flag lives on Global and is cleared in dice_interface.gd's start-of-turn block next to
# charged_dice_this_turn, because relics are shared .tres singletons - relic_handler assigns
# them without duplicating, so per-turn state on the resource would leak across runs.


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.echo_chamber_fired_this_turn:
        return
    var h: Array = Global.roll_history
    if h.size() < 2 or h[h.size() - 1] != h[h.size() - 2]:
        return
    Global.echo_chamber_fired_this_turn = true
    owner.flash()
    Global.blue_dice_current_amount += 1
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("blue", 1)
    Events.temporary_dice_added.emit("blue")


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
