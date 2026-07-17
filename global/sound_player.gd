extends Node

# Pooled SFX player backing the SFXPlayer autoload (see sfx_player.tscn - 8 AudioStreamPlayer
# children). Previously, if all 8 were busy, play() just silently did nothing - found by Julien
# playing fast: the Recombobulate refuel sound could go missing entirely, most likely because
# the power-orb landing plinks (dice.gd::_spawn_power_orbs, up to ~15 per big roll, each firing
# its own play() call) can occupy several voices at once during a fast-paced turn, leaving none
# free for whatever else wants to play a beat later.
#
# Fix: never drop a sound outright. If every voice is busy, steal one instead - preferring to
# steal the lowest-priority voice currently playing. Decorative sounds (the orb-land plinks)
# pass priority=-1 specifically so they're always the first to get cut; everything else keeps
# the default priority=0 and only steals another priority-0 voice if the pool is completely
# full of them (better than silently doing nothing, which was the actual bug).

var _priorities := {}  # AudioStreamPlayer -> int, only meaningful while that player is playing


func play(
    audio: AudioStream, single := false, pitch_scale := 1.0, volume_db := 0.0, priority := 0
) -> void:
    if not audio:
        return

    if single:
        stop()

    var player := _find_free_player()
    if player == null:
        player = _find_stealable_player(priority)
    if player == null:
        # Every voice is busy with something at least as important as this one - drop it
        # rather than cut off something equally deserving. Should be vanishingly rare now
        # that stealing exists at all.
        return

    _priorities[player] = priority
    player.stream = audio
    # Always set both explicitly (not just when non-default) - players are pooled and
    # reused across unrelated sfx calls, so a leftover pitch/volume from a previous
    # customized play() would otherwise leak onto the next sound that didn't ask for it.
    player.pitch_scale = pitch_scale
    player.volume_db = volume_db
    player.play()


func stop() -> void:
    for player: AudioStreamPlayer in get_children():
        player.stop()
    _priorities.clear()


func _find_free_player() -> AudioStreamPlayer:
    for player: AudioStreamPlayer in get_children():
        if not player.playing:
            return player
    return null


# Picks the currently-playing voice with the lowest priority to steal, but only among
# voices whose priority is <= the incoming sound's - so a normal-priority sound always
# wins against a low-priority one, but two equally-important sounds fight fairly (first
# one found loses) instead of the newest one always losing (i.e. being dropped).
func _find_stealable_player(incoming_priority: int) -> AudioStreamPlayer:
    var best: AudioStreamPlayer = null
    var best_priority := 999999
    for player: AudioStreamPlayer in get_children():
        var p: int = _priorities.get(player, 0)
        if p <= incoming_priority and p < best_priority:
            best = player
            best_priority = p
    return best
