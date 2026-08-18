extends Card

# THE Exposed payoff (Julien, 2026-08-16). Exposed had four applicators - Rupture, Smash,
# Corrode, the old Dominance - and nothing that cashed it in, so they all blurred together.
# This spends the debuff instead of adding a fifth way to apply it, which makes the other
# three retroactively better.
#
# Two SEPARATE hits rather than one doubled lump: each pass goes through the target's own
# DMG_TAKEN modifiers, so Exposed's own multiplier applies to both - and each lands with its
# own popup/hit-stop, the same reason Flurry was reworked into two strikes.

const HIT_INTERVAL := 0.2


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Events.reset_charged_card.emit()
    if targets.is_empty():
        Events.dice_roll_reset.emit()
        return
    var target: Node = targets[0]
    var damage := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    _strike(target, damage)
    if _is_exposed(target):
        # Pause-safe timer, and the target is re-validated on arrival - it may have died to
        # the first hit (same pattern as stampede.gd / the thrown-die landings).
        var timer := target.get_tree().create_timer(HIT_INTERVAL, false)
        timer.timeout.connect(_on_second_hit.bind(target, damage))
    Events.dice_roll_reset.emit()


func _on_second_hit(target: Node, damage: int) -> void:
    if target == null or not is_instance_valid(target):
        return
    _strike(target, damage)


func _strike(target: Node, damage: int) -> void:
    var damage_effect := DamageEffect.new()
    damage_effect.amount = damage
    damage_effect.sound = sound
    damage_effect.execute([target])


func _is_exposed(target: Node) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    var handler = target.get("status_handler")
    if handler == null:
        return false
    return handler._has_status("exposed")


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage, twice against Exposed enemies"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage, twice against Exposed enemies"
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    if _is_exposed(target):
        return "Deal X damage, twice against Exposed enemies (%d + %d)" % [total, total]
    return "Deal X damage, twice against Exposed enemies (%d)" % total
