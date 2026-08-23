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
            damage_popup.global_position = popup_origin if popup_origin != Vector2.ZERO \
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
