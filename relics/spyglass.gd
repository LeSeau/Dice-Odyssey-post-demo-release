extends Relic

# Back in the pool on 2026-08-31 (Julien) with a new job. The old Spyglass handed out a
# Scout 2 card the first time Power passed 12 each turn; this one upgrades the Scouts you
# already play, which is a build payoff rather than a second copy of Flywheel.
#
# Purely passive - battle.gd::_on_scout_effect() reads Global.scout_unique_faces and draws
# its faces without replacement, so no outcome is ever offered twice. Stacks naturally with
# Cartographer's Quill: wider Scout + no duplicates means a Scout 6 on a d6 shows every face,
# which is what makes this Rare.
#
# Set on initialize/cleared on deactivate rather than per-battle: the RelicHandler lives in
# run.tscn and survives every scene change, so a relic is only ever deactivated when it is
# actually removed (same lifecycle as Haggler's Loupe).


func initialize_relic(_owner: RelicUI) -> void:
    Global.scout_unique_faces = true


func deactivate_relic(_owner: RelicUI) -> void:
    Global.scout_unique_faces = false
