extends Relic

# Strength for rolling badly - the Low Roll archetype's scaling payoff, opposite Conductor's
# Baton (immediate chip damage on the same trigger).
#
# ⚠️ DELIBERATELY UNCAPPED: every 1 pays, however many land in a turn. A once-per-turn cap was
# tried on 2026-08-31 and reverted the same day (Julien) - the dice that roll 1s most often
# (Green d3, Pixie, anything under Weak) are exactly the ones this relic is for, and capping it
# punished the build it exists to reward. Do not re-add triggered_this_turn here.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1:
        return
    _grant_strength(owner)


func _grant_strength(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var status_effect := StatusEffect.new()
    # Shared preloaded resource - duplicate before touching stacks (see giants_signet.gd).
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 1
    status_effect.status = muscle
    status_effect.execute([player])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
