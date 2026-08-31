extends Relic

# Strength for rolling badly - the Low Roll archetype's scaling payoff, opposite Conductor's
# Baton (immediate chip damage on the same trigger).
#
# Capped at once per turn since 2026-08-31 (Julien). Uncapped it paid per 1 rolled, so the
# dice that produce 1s most often - Green d3, Pixie, a Weak-ed die - turned it into several
# permanent Strength per turn, i.e. the relic scaled fastest exactly where the rolls were
# worst. The cap keeps the archetype's reward without the runaway; same triggered_this_turn
# shape as Runic Bones and Sledgehammer.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

var triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    triggered_this_turn = false
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if triggered_this_turn or Global.last_roll != 1:
        return
    triggered_this_turn = true
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


func _on_player_turn_started() -> void:
    triggered_this_turn = false


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
