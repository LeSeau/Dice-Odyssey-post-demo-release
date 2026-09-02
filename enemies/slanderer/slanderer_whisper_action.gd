extends EnemyAction

const SLANDER_CARD_PATH := "res://characters/warrior/cards/card_slander.tres"

@export var damage := 4
var base_damage = damage


# Never twice in a row: two Slanderers each capped at 1 still put roughly four junk cards in
# a five-turn fight, which is already a heavy first dose. Without the cap a bad streak buries
# the deck.
func is_performable() -> bool:
    return not hit_consecutive_cap(1)

func perform_action() -> void:
    if not enemy or not target:
        return

    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound

    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_callback(_plant_slander)
    # The Slanderer stays in your face while the card it planted is presented on the stage
    # (junk_plant_presenter.gd) and walks back exactly as it flies off to the pile. Holding
    # the lunge is what keeps the beat ON ITS MOVE: without it the next enemy's lunge would
    # cross behind the card mid-read, which is precisely the case in its own paired fight.
    tween.tween_interval(Global.JUNK_PLANT_PRESENT_TIME)
    tween.tween_property(enemy, "global_position", start, 0.4)

    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage


func _plant_slander() -> void:
    # duplicate() because load() is ResourceLoader-cached by path: handing out the same Card
    # object twice gives two CardUI nodes one instance_id, and both then resolve as "the"
    # played card at once (same trap documented in calculations.gd).
    var card: Card = load(SLANDER_CARD_PATH).duplicate()
    # enemy.tscn bakes the Sprite2D at x=124, so the node's own global_position sits well to
    # the LEFT of the drawn body - the sprite is the honest place for the card to leave from.
    var origin := Vector2.ZERO
    if is_instance_valid(enemy) and enemy.sprite_2d != null:
        origin = enemy.sprite_2d.global_position
    Events.add_card_to_discard_requested.emit(card, origin)
