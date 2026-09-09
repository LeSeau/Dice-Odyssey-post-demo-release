extends Relic

# The pool's first relic that applies a DEBUFF, and it is tied to the socket rather than to
# a roll: every card you commit to the Red die softens what it hits for the follow-up.
#
# Exposed's number is DURATION, not magnitude (it is always +50% taken), so 1 means "until
# your next turn" - enough to make the socketed card set up the rest of the turn, not enough
# to stack into permanent vulnerability.
#
# ⚠️ ORDERING IS THE WHOLE POINT (Julien, 2026-09-09: "38 damage becomes 57 AND exposed1").
# The debuff must land AFTER the card's own damage, never before it - "deal damage, THEN
# expose". The Red socket window (Global.playing_red_card) only exists during card_played,
# which fires on Card.play()'s FIRST line, so the decision is made there and the APPLICATION
# is deferred to Events.card_damage_resolved. That second signal is also what covers the
# held-die strike, which flies for ~0.26s before its hit resolves.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const EXPOSED_DURATION := 1

# Enemies chosen at card_played time, waiting for that card's damage to land. Snapshotted by
# value: Global.playing_red_card and Global.last_played_card_targets are both gone/overwritten
# by the time the deferred path fires.
var _pending_targets: Array[Node] = []
var _pending_owner: RelicUI = null


func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played.bind(owner))
    Events.card_damage_resolved.connect(_on_card_damage_resolved)


func _on_card_played(_card: Card, owner: RelicUI) -> void:
    # A pending debuff that never got its resolve signal (the fight ended while the strike was
    # mid-flight, so the impact callback died with the scene) is applied now rather than
    # dropped: late is still after the damage that earned it, which is the contract.
    _flush_pending()

    # True for exactly the window in which a socketed card is resolved from a Red roll
    # (dice.gd sets it, both the instant and the aim-then-release path clear it after).
    if not Global.playing_red_card:
        return
    # Card.play() resolves its target list into this BEFORE emitting card_played, precisely
    # so relics can read it. Filtered to enemies: a Red-socketed Block card targets the
    # player, and Exposed on yourself would be a downgrade rather than a bonus.
    var enemies: Array[Node] = []
    for candidate in Global.last_played_card_targets:
        if is_instance_valid(candidate) and candidate is Enemy:
            enemies.append(candidate)
    if enemies.is_empty():
        return
    _pending_targets = enemies
    _pending_owner = owner


func _on_card_damage_resolved() -> void:
    _flush_pending()


func _flush_pending() -> void:
    if _pending_targets.is_empty():
        return
    var enemies: Array[Node] = []
    for candidate in _pending_targets:
        # The card may well have killed them - Exposed on a corpse is a no-op, and a freed
        # node would take the StatusEffect down with it.
        if is_instance_valid(candidate) and candidate is Enemy:
            enemies.append(candidate)
    var owner := _pending_owner
    _pending_targets = []
    _pending_owner = null
    if enemies.is_empty():
        return
    if owner != null and is_instance_valid(owner):
        owner.flash()
    var status_effect := StatusEffect.new()
    var exposed: Status = EXPOSED_STATUS.duplicate()
    exposed.duration = EXPOSED_DURATION
    status_effect.status = exposed
    status_effect.execute(enemies)


func deactivate_relic(_owner: RelicUI) -> void:
    _pending_targets = []
    _pending_owner = null
    if Events.card_played.is_connected(_on_card_played):
        Events.card_played.disconnect(_on_card_played)
    if Events.card_damage_resolved.is_connected(_on_card_damage_resolved):
        Events.card_damage_resolved.disconnect(_on_card_damage_resolved)
