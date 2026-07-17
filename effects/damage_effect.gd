class_name DamageEffect
extends Effect

var amount := 0
var receiver_modifier_type := Modifier.Type.DMG_TAKEN
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
            elif target is Player:
                AchievementManager.report_player_hit(Global.damage_to_display, target.stats.health > 0)
            var is_big_hit := final_amount >= BIG_HIT_THRESHOLD

            var camera = target.get_tree().get_first_node_in_group("camera")
            if camera:
                # Higher floor + steeper curve so bread-and-butter 6-8 dmg hits (previously
                # only ~3-4px, imperceptible) actually register, while big hits still cap out.
                camera.shake(clampf(final_amount * 0.7 + 2.5, 5.0, 18.0), 0.15)
                if is_big_hit:
                    camera.punch_zoom(BIG_HIT_ZOOM_PUNCH)

            # Steepened + raised the ceiling (2026-07-04, was clampf(amount*0.008, 0.04, 0.16))
            # so a genuinely big hit (~12+ damage early-run) reads as a noticeably bigger freeze
            # than a routine one, rather than everything past ~20 damage feeling the same. Floor
            # kept at 0.04 - small hits weren't the complaint.
            Shaker.hit_stop(clampf(final_amount * 0.014, 0.04, 0.24))

            var damage_popup = DAMAGE_POPUP_SCENE.instantiate()
            target.get_parent().add_child(damage_popup)
            damage_popup.global_position = target.global_position
            damage_popup.fade_duration = 1.0
            damage_popup.show_damage(Global.damage_to_display)

            var hit_pitch := clampf(1.12 - final_amount * 0.01, 0.82, 1.12)
            var hit_volume_db := clampf(
                HIT_SFX_BASE_VOLUME_DB + final_amount * HIT_SFX_VOLUME_PER_DAMAGE,
                HIT_SFX_BASE_VOLUME_DB, HIT_SFX_VOLUME_MAX_DB)
            SFXPlayer.play(sound, false, hit_pitch, hit_volume_db)
