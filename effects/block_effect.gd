class_name BlockEffect
extends Effect

const BLOCK_POPUP_SCENE := preload("res://scenes/ui/block_popup.tscn")

# --- Ward VFX (2026-08-18) --------------------------------------------------------------
# Blocking used to be the quietest beat in combat: a drifting "+N" and a sound, nothing on
# the body itself. The ward reuses the established juice language rather than inventing one:
# an additive ring (DicePalette.ring_texture) plus MASS in the form of shards. The shards
# converge INWARD, which is what separates this from every other effect in the game - hits
# and charges throw particles outward, armour assembles.
# The player's ward takes the ACTIVE DICE colour - blocking is something you did with a
# specific die, and every other player-side beat (power orbs, damage popups, card
# particles) is already tinted that way. DicePalette.accent is infusion-aware, so an
# infused die tints the ward for free.
# ENEMY block stays a fixed icy blue: it matches the shield badge on the health bar and,
# more importantly, an enemy blocking has nothing to do with which die YOU are holding.
const WARD_COLOR_ENEMY := Color(0.47, 0.78, 1.0)
const WARD_Z := 8  # above the enemy sprite (z=7), below its intent (z=10)
const WARD_SHARDS := 10
const WARD_RING_TIME := 0.34
const WARD_SHARD_TIME := 0.26

var amount := 0


func execute(targets: Array[Node]) -> void:
    for target in targets:
        if not target:
            continue
        if target is Enemy or target is Player:
            target.stats.block += amount
            SFXPlayer.play(sound)

            var tint := _ward_color(target)
            var tint_centre := Card.thrown_impact_pos(target)

            var block_popup = BLOCK_POPUP_SCENE.instantiate()
            target.get_parent().add_child(block_popup)
            # Match the ward: the popup used the enemy ROOT, which sits ~124px left of
            # the art, so the number floated beside the body while the ward sat on it.
            block_popup.global_position = tint_centre
            block_popup.show_block(amount, tint)

            _spawn_ward(target, tint)


# Scaled by the block granted, on the same "ladder" principle the roll/impact feel uses: a
# 5-block chip and a 20-block Barricade should not look identical.
func _ward_color(target: Node) -> Color:
    if target is Player:
        return DicePalette.accent(Global.dice_type)
    return WARD_COLOR_ENEMY


func _spawn_ward(target: Node, tint: Color) -> void:
    var parent := target.get_parent()
    if parent == null:
        return
    var strength := clampf(float(amount) / 20.0, 0.35, 1.0)
    var radius := 74.0 + 34.0 * strength
    # Body centre, NOT target.global_position: an Enemy's root sits ~124px left of its art
    # (the Sprite2D carries a baked offset), so the raw root position would park the ward
    # beside the body. Card.thrown_impact_pos already solves this for thrown dice and falls
    # back sanely for the Player, so reuse it rather than re-deriving the offset here.
    var centre := Card.thrown_impact_pos(target)

    var ring := Sprite2D.new()
    ring.texture = DicePalette.ring_texture()
    ring.material = DicePalette.additive_material()
    ring.z_index = WARD_Z
    ring.modulate = Color(tint.r, tint.g, tint.b, 0.0)
    parent.add_child(ring)
    ring.global_position = centre
    var ring_scale := (radius * 2.0) / float(ring.texture.get_width())
    ring.scale = Vector2.ONE * ring_scale * 1.32

    # Snap in, hold a beat, fade. The ring CONTRACTS onto the body (1.32 -> 1.0) instead of
    # expanding away from it - an expanding ring is the visual grammar of an explosion.
    var ring_tween := ring.create_tween()
    ring_tween.set_parallel(true)
    ring_tween.tween_property(ring, "scale", Vector2.ONE * ring_scale, WARD_RING_TIME) \
        .set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    # Alpha on its own timeline: a peak held across the whole scale would read as a wash
    # rather than a snap (the documented additive-stacking trap).
    var alpha_tween := ring.create_tween()
    alpha_tween.tween_property(ring, "modulate:a", 0.55 + 0.35 * strength, 0.07) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    alpha_tween.tween_interval(0.06)
    alpha_tween.tween_property(ring, "modulate:a", 0.0, WARD_RING_TIME - 0.13) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    alpha_tween.tween_callback(ring.queue_free)

    # Shards: the mass that makes the beat land (lesson from the slash pass - the eye reads
    # MASS before shape). They fly in from outside the ring and wink out as they arrive.
    var shard_count := int(round(WARD_SHARDS * (0.6 + 0.4 * strength)))
    for i in shard_count:
        var angle := TAU * (float(i) / float(shard_count)) + randf_range(-0.18, 0.18)
        var dist := radius * randf_range(1.15, 1.55)
        var shard := Sprite2D.new()
        shard.texture = DicePalette.glow_texture()
        shard.material = DicePalette.additive_material()
        shard.z_index = WARD_Z
        var shard_px := randf_range(11.0, 20.0) * (0.75 + 0.45 * strength)
        shard.scale = Vector2.ONE * (shard_px / float(shard.texture.get_width()))
        shard.modulate = Color(tint.r, tint.g, tint.b, 0.0)
        parent.add_child(shard)
        var home := centre
        shard.global_position = home + Vector2.RIGHT.rotated(angle) * dist

        var delay := randf_range(0.0, 0.07)
        var shard_tween := shard.create_tween()
        shard_tween.tween_interval(delay)
        shard_tween.set_parallel(true)
        shard_tween.tween_property(shard, "global_position",
                home + Vector2.RIGHT.rotated(angle) * (radius * 0.82), WARD_SHARD_TIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        shard_tween.tween_property(shard, "modulate:a", 0.85, WARD_SHARD_TIME * 0.45) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        var fade := shard.create_tween()
        fade.tween_interval(delay + WARD_SHARD_TIME * 0.55)
        fade.tween_property(shard, "modulate:a", 0.0, WARD_SHARD_TIME * 0.45) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        fade.tween_callback(shard.queue_free)
