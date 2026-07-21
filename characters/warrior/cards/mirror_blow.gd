extends Card

# Deal the enemy's own intended attack back at them (Odd requirement). The number is read
# from the intent the player is looking at: the action's formatted intent text (single
# "12" or multi-hit "6x2" both handled), gated on the action actually being an attack
# (duck-typed on its exported `damage` - block/buff intents deal 0 back).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var damage := _intent_damage(targets[0])
    var damage_effect := DamageEffect.new()
    damage_effect.amount = damage
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _intent_damage(target: Node) -> int:
    if target == null or not is_instance_valid(target):
        return 0
    var action = target.get("current_action")
    if action == null or not ("damage" in action):
        return 0
    var text := ""
    if action.intent != null:
        text = str(action.intent.current_text)
    var multi := RegEx.new()
    multi.compile("(\\d+)\\s*x\\s*(\\d+)")
    var m := multi.search(text)
    if m:
        return int(m.get_string(1)) * int(m.get_string(2))
    var single := RegEx.new()
    single.compile("\\d+")
    m = single.search(text)
    if m:
        return int(m.get_string())
    return 0


func get_dynamic_description(_modifiers: ModifierHandler, target: Node = null) -> String:
    if target == null or not is_instance_valid(target) or not meets_requirement():
        return "Deal damage equal to the enemy's intended attack"
    return "Deal damage equal to the enemy's intended attack (%d)" % _intent_damage(target)
