class_name EarthquakeStatus
extends Status

# The Earthquake card banks its damage into `stacks` (player-modified X2, locked at play
# time) - the stacks badge doubles as the "incoming quake" number the player sees under
# their HP bar during the enemy turn. can_expire + duration 1 makes this one-shot: the
# START_OF_TURN apply below fires once, then StatusHandler's decrement removes the icon.
# Replaying the card the same turn INTENSITY-stacks the damage into one bigger quake.

const HIT_SOUND := preload("res://impact1.ogg")


func apply_status(target: Node) -> void:
    if stacks > 0 and target and is_instance_valid(target):
        var damage_effect := DamageEffect.new()
        damage_effect.amount = stacks
        damage_effect.sound = HIT_SOUND
        damage_effect.execute(target.get_tree().get_nodes_in_group("enemies"))
    status_applied.emit(self)
