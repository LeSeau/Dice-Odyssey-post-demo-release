extends Relic

# One guaranteed jackpot per fight. The Red die is the gamble die, so the fantasy here is
# palming a loaded one for a single throw rather than removing the gamble permanently.
#
# The forcing itself lives in dice.gd's roll path (it needs the face list, which an infusion
# can rewrite). This script only owns the arming: set at the start of every fight, and also
# right now, so picking the relic up mid-combat is not a dead pickup.


func initialize_relic(owner: RelicUI) -> void:
    Global.marked_deck_armed = true
    Events.battle_started.connect(_on_battle_started.bind(owner))


func _on_battle_started(owner: RelicUI) -> void:
    Global.marked_deck_armed = true
    owner.flash()


func deactivate_relic(_owner: RelicUI) -> void:
    Global.marked_deck_armed = false
    if Events.battle_started.is_connected(_on_battle_started):
        Events.battle_started.disconnect(_on_battle_started)
