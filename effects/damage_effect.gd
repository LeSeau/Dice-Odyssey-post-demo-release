class_name DamageEffect
extends Effect

var amount := 0
var receiver_modifier_type := Modifier.Type.DMG_TAKEN
# Optional popup spawn override (ZERO = default, the target's root position). Thrown-dice
# hits set this to the die's impact point (Card.thrown_impact_pos) so each number in a
# sequenced volley pops off the exact spot its die smashed.
var popup_origin := Vector2.ZERO
const DAMAGE_POPUP_SCENE := preload("res://scenes/ui/damage_popup.tscn")  # or whereve

# Hits at/above this get an extra camera punch zoom (below) on top of the always-on
# shake/hit-stop/popup - keeps routine damage uncluttered while making genuinely big
# blows feel distinctly bigger, not just louder repeats.
const BIG_HIT_THRESHOLD := 15
const BIG_HIT_ZOOM_PUNCH := 0.045

# Bigger hits land lower-pitched and louder for a heavier "thud" instead of every hit
# sounding identical regardless of size. Base volume raised (was a 0dB floor, felt too
# quiet even on routine hits) - scaling only ever ADDS from there, never below it, up to
# a cap for the biggest hits.
const HIT_SFX_BASE_VOLUME_DB := 3.0
const HIT_SFX_VOLUME_PER_DAMAGE := 0.18
const HIT_SFX_VOLUME_MAX_DB := 8.0

# Held-die strike (2026-08-28). At or above this rung the hero's die stops merely thrusting
# and physically flies into the body; a lethal hit qualifies at any size, because a kill is
# the beat worth the ceremony regardless of how big the number was.
# Literal rather than Shaker.Impact.STRONG: an autoload is not available at parse time, so
# the enum cannot be folded into a const. VERY_WEAK 0, WEAK 1, MEDIUM 2, STRONG 3, HUGE 4.
const STRIKE_MIN_TIER := 3



func execute(targets: Array[Node]) -> void:
    for target in targets:
        if not target or not is_instance_valid(target):
            continue
        if target is Enemy or target is Player:
            # Berserker infusion: the socketed card played by a Red roll deals +50%,
            # rounded UP so it always feels generous. Enemy targets only - self-damage
            # (e.g. a backfire) must not get punished by the player's own infusion.
            var final_amount := amount
            if Global.berserker_boost_active and target is Enemy:
                final_amount = ceili(amount * 1.5)

            # The hero's held die answers this hit: a laddered thrust, or - on a big or
            # lethal single-target blow - the die itself flying out to deliver it. When the
            # strike takes the hit, _resolve_hit runs on the die's impact instead of now.
            if target is Enemy and Global.last_attack_card_played_frame == Engine.get_process_frames():
                var impact := Shaker.impact_for_damage(final_amount)
                if _try_die_strike(target, final_amount, int(impact)):
                    continue
                _react_held_die(int(impact), final_amount)

            _resolve_hit(target, final_amount)


# Everything that happens when a hit actually lands. Extracted verbatim so the immediate path
# above and the deferred (die-strike) path below run the SAME code - a hand-copied subset is
# how two paths quietly drift apart. Note the ordering is load-bearing: take_damage writes
# Global.damage_to_display / blocked_to_display, and every reporter and the popup below read
# them, so nothing may be reordered across that call.
func _resolve_hit(target: Node, final_amount: int, origin_override := Vector2.ZERO) -> void:
    if target == null or not is_instance_valid(target):
        return
    # Overkill achievement needs the target's HP BEFORE this hit lands.
    var hp_before := 0
    if target is Enemy:
        hp_before = target.stats.health
    target.take_damage(final_amount, receiver_modifier_type)
    # Kaboom achievement: report the target-modified damage (take_damage just wrote
    # it into damage_to_display) - no-ops unless a card play window is open.
    if target is Enemy:
        AchievementManager.track_card_damage(Global.damage_to_display)
        AchievementManager.report_enemy_hit(hp_before, Global.damage_to_display)
        # End-of-run screens: any damage on an Enemy is player-caused
        # (enemies never hit each other), so this IS the player's biggest hit.
        Global.run_stat_biggest_hit = maxi(Global.run_stat_biggest_hit, Global.damage_to_display)
    elif target is Player:
        AchievementManager.report_player_hit(Global.damage_to_display, target.stats.health > 0)
        Global.run_stat_damage_taken += Global.damage_to_display
        # Thorns-style relics (Thorned Plate) key off a PERFECT block. Same test the
        # popup below uses to show "Blocked" instead of a red number, so the relic
        # can never disagree with what the player was just shown.
        if Global.damage_to_display <= 0 and Global.blocked_to_display > 0:
            Events.player_fully_blocked.emit(Global.acting_enemy)
    var is_big_hit := final_amount >= BIG_HIT_THRESHOLD

    # One ladder rung drives shake AND hit-stop together (2026-08-15, STS2 audit
    # 4.2/4.3), replacing two independent hand-tuned clampf curves. Shake outlasts
    # the freeze at every rung by construction, so you come out of the slow-motion
    # while the screen is still moving - recoil, not a hitch.
    var impact := Shaker.impact_for_damage(final_amount)

    var camera = target.get_tree().get_first_node_in_group("camera")
    if camera:
        camera.shake(Shaker.SHAKE_MAGNITUDE[impact], Shaker.SHAKE_DURATION[impact])
        if is_big_hit:
            camera.punch_zoom(BIG_HIT_ZOOM_PUNCH)

    Shaker.hit_stop_impact(impact)

    var damage_popup = DAMAGE_POPUP_SCENE.instantiate()
    target.get_parent().add_child(damage_popup)
    # origin_override is the die's impact point on a strike; popup_origin is the thrown-dice
    # override; falling through to the target root is the default.
    var origin: Vector2 = origin_override if origin_override != Vector2.ZERO else popup_origin
    damage_popup.global_position = origin if origin != Vector2.ZERO \
            else target.global_position
    damage_popup.fade_duration = 1.0
    # Fully-blocked hit: no red "-6" lying about HP loss - the shield ate it all.
    # A hit that is 0 for any OTHER reason keeps the plain number.
    if Global.damage_to_display <= 0 and Global.blocked_to_display > 0:
        damage_popup.show_blocked()
    else:
        damage_popup.show_damage(Global.damage_to_display)

    var hit_pitch := clampf(1.12 - final_amount * 0.01, 0.82, 1.12)
    var hit_volume_db := clampf(
        HIT_SFX_BASE_VOLUME_DB + final_amount * HIT_SFX_VOLUME_PER_DAMAGE,
        HIT_SFX_BASE_VOLUME_DB, HIT_SFX_VOLUME_MAX_DB)
    SFXPlayer.play(sound, false, hit_pitch, hit_volume_db)


# --- Held-die reaction ---------------------------------------------------------------------

# Laddered thrust. Once per frame, keyed on the LARGEST hit of that frame: an AoE card runs
# one execute() per target within a single frame, and the hero should answer the card, not
# repunch per body.
func _react_held_die(impact: int, final_amount: int) -> void:
    var frame := Engine.get_process_frames()
    if Global.die_reaction_frame != frame:
        Global.die_reaction_frame = frame
        Global.die_reaction_best_amount = -1
    if final_amount <= Global.die_reaction_best_amount:
        return
    Global.die_reaction_best_amount = final_amount
    var player := Global.player
    if player != null and is_instance_valid(player):
        player.punch_held_die_for_impact(impact)


# Would this hit kill? Mirrors exactly what take_damage is about to compute (target-side
# modifiers first, then block soaking before HP), so an Exposed enemy is read as lethal when
# it genuinely is - rather than guessing from the raw number.
func _is_lethal(target: Node, final_amount: int) -> bool:
    if not (target is Enemy) or target.stats == null:
        return false
    var modified := final_amount
    if target.modifier_handler != null:
        modified = target.modifier_handler.get_modified_value(final_amount, receiver_modifier_type)
    return modified >= target.stats.health + target.stats.block


# Launches the die if this hit has earned it, and returns true once the hit has been handed
# over - the caller must then NOT resolve it, because the strike owns it now.
func _try_die_strike(target: Node, final_amount: int, impact: int) -> bool:
    # Single-target only in v1: a die flying through a crowd is a different animation.
    if not Global.last_attack_card_single_target:
        return false
    # Cards that read their target's state after damaging it cannot have that damage moved
    # out from under them (Card.observes_post_damage).
    if Global.playing_card_observes_post_damage:
        return false
    var frame := Engine.get_process_frames()
    if Global.die_strike_frame == frame:
        return false  # one strike per card play
    var lethal := _is_lethal(target, final_amount)
    if impact < STRIKE_MIN_TIER and not lethal:
        return false
    var player := Global.player
    if player == null or not is_instance_valid(player):
        return false

    # Snapshot BY VALUE. Card.play() clears berserker_boost_active as soon as apply_effects
    # returns, which is long before this lands - so the boosted number has to be carried, not
    # recomputed. Same reason All In pre-multiplies its deferred lump.
    var snapshot_amount := final_amount
    var effect := self
    var tree := player.get_tree()
    var on_impact := func() -> void:
        var final_target := target
        # The target can die to something else mid-flight (a status tick, a thorns reflect).
        # Bounce to a living enemy exactly like a thrown die does; if the fight is already
        # over, the die simply lands on nothing.
        if final_target == null or not is_instance_valid(final_target) \
                or not final_target.is_in_group("enemies"):
            var alive := tree.get_nodes_in_group("enemies")
            if alive.is_empty():
                return
            final_target = alive[randi() % alive.size()]
        # The Kaboom window is opened and closed synchronously inside Card.play(), so a hit
        # deferred past it would go uncounted - on precisely the biggest hits, which are the
        # only ones that could earn the achievement. Re-open one around the deferred hit:
        # the strike is single-target and once per play, so this hit IS the card's damage.
        AchievementManager.begin_card_damage_window()
        effect._resolve_hit(final_target, snapshot_amount, Card.thrown_impact_pos(final_target))
        AchievementManager.end_card_damage_window()

    if not player.strike_with_die(target, on_impact, lethal):
        return false
    Global.die_strike_frame = frame
    return true
