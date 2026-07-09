extends Node


func play(audio: AudioStream, single=false, pitch_scale := 1.0, volume_db := 0.0) -> void:
    if not audio:
        return

    if single:
        stop()

    for player: AudioStreamPlayer in get_children():
        if not player.playing:
            player.stream = audio
            # Always set both explicitly (not just when non-default) - players are pooled and
            # reused across unrelated sfx calls, so a leftover pitch/volume from a previous
            # customized play() would otherwise leak onto the next sound that didn't ask for it.
            player.pitch_scale = pitch_scale
            player.volume_db = volume_db
            player.play()
            break


func stop() -> void:
    for player: AudioStreamPlayer in get_children():
        player.stop()
