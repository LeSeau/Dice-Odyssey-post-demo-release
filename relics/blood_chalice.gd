extends Relic

# The pool's first relic that applies a DEBUFF, and it is tied to the socket rather than to
# a roll: every card you commit to the Red die softens what it hits for the follow-up.
#
# Exposed's number is DURATION, not magnitude (it is always +50% taken), so 1 means "until
# your next turn" - enough to make the socketed card set up the rest of the turn, not enough
# to stack into permanent vulnerability.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const EXPOSED_DURATION := 1


func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played.bind(owner))


func _on_card_played(_card: Card, owner: RelicUI) -> void:
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
    owner.flash()
    var status_effect := StatusEffect.new()
    var exposed: Status = EXPOSED_STATUS.duplicate()
    exposed.duration = EXPOSED_DURATION
    status_effect.status = exposed
    status_effect.execute(enemies)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.card_played.is_connected(_on_card_played):
        Events.card_played.disconnect(_on_card_played)
