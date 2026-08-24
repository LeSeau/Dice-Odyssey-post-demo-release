extends Relic

# Pays once per fight, when the Power you have refuelled ADDS UP to 20 (Julien, 2026-08-24).
# Cumulative on purpose: three panic Recombobulates at 7 Power each pay exactly the same as
# one huge one, so this rewards a deck that refuels as a habit rather than one lucky blowout.
#
# The accumulator lives on Global (reset in battle.gd::start_battle) because relics are
# shared .tres singletons - relic_handler assigns them without duplicating, so a counter
# stored on the resource itself would leak into the next run.
#
# "Once per fight" needs no extra flag: the total only ever grows, so the crossing test
# below is true on exactly one refuel.

const THRESHOLD := 20
const STRENGTH := 3
const MUSCLE_STATUS = preload("res://statuses/muscle.tres")


func initialize_relic(owner: RelicUI) -> void:
    Events.refuel_happened.connect(_on_refuel_happened.bind(owner))
    Events.battle_started.connect(_on_battle_started.bind(owner))
    _update_counter(owner)


func _on_battle_started(owner: RelicUI) -> void:
    _update_counter(owner)


func _on_refuel_happened(amount, owner: RelicUI) -> void:
    var before: int = Global.refueled_power_this_fight
    Global.refueled_power_this_fight = before + int(amount)
    _update_counter(owner)
    # Fires only on the refuel that carries the total ACROSS the line, never again after.
    if before >= THRESHOLD or Global.refueled_power_this_fight < THRESHOLD:
        return

    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = STRENGTH
    status_effect.status = muscle
    status_effect.execute([player])


# Counts up to 20 and stops, so the player can see how much more refuelling is worth doing.
func _update_counter(owner: RelicUI) -> void:
    owner.counter.text = str(mini(Global.refueled_power_this_fight, THRESHOLD))
    owner.counter.visible = true


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.refuel_happened.is_connected(_on_refuel_happened):
        Events.refuel_happened.disconnect(_on_refuel_happened)
    if Events.battle_started.is_connected(_on_battle_started):
        Events.battle_started.disconnect(_on_battle_started)
