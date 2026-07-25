class_name IntentUI
extends HBoxContainer

const TooltipScene = preload("res://scenes/ui/intent_tooltip.tscn")

# Slay-the-Spire-style intent motion: the icon simply floats UP AND DOWN, forever. That's
# the whole thing - no scale pulse, no pop on change.
#   * Position, never scale. The first version pulsed `scale` 1.0<->1.07, and rescaling a
#     60px sprite by a few percent every frame resamples its edges continuously, which
#     shimmers instead of breathing - Julien read it as "a bit shaky". Translating it
#     vertically leaves the sprite untouched, so it stays crisp while it moves.
#   * Icon AND number together, as one telegraph (Julien, 2026-07-25). A first pass moved
#     only the icon to keep the damage figure rock-steady; he wanted them locked together,
#     and a number pinned while its own icon drifts does read as two separate things.
#   * On the children, never on `self`: enemy.gd owns IntentUI's own position/scale/pivot_offset
#     (it counter-scales against the enemy's scale and pins the telegraph above its head).
#     That's almost certainly why the scene's old AnimationPlayer bob targeted `.:position`
#     with tracks/0/enabled = false - i.e. it animated nothing at all. That dead
#     AnimationPlayer was removed when this replaced it; don't add one back.
# Both sit inside wrapper Controls (`IconSlot` / `LabelSlot`) for this: a DIRECT child of
# the HBoxContainer has its position overwritten every time the container re-sorts, which
# happens whenever the damage number changes width (7 -> 13), and that would snap the bob
# mid-flight. The slots are what the container lays out; the nodes inside them are free to
# move. LabelSlot's width has to be kept in sync with the text by hand (see
# _sync_label_slot) because a plain Control does not track its child's minimum size.
const BOB_DISTANCE := 6.0
const BOB_HALF_TIME := 0.9
const ROW_HEIGHT := 60.0

@onready var icon: TextureRect = $IconSlot/Icon
@onready var label: Label = $LabelSlot/Label
@onready var label_slot: Control = $LabelSlot

var tooltip_instance = null
var _bob_tween: Tween
# Per-instance period. Every IntentUI starts its bob in _ready(), so a shared period would
# have a whole row of enemies rising and falling in lockstep - reads mechanical. A few
# percent of jitter drifts them apart within one cycle.
var _bob_half := BOB_HALF_TIME


func _ready() -> void:
    _bob_half = BOB_HALF_TIME * randf_range(0.88, 1.12)
    label.minimum_size_changed.connect(_sync_label_slot)
    _sync_label_slot()
    _start_bob()


# Keeps the laid-out width of the number's slot equal to the number's own width, so the
# HBoxContainer still centres icon+number exactly as it did when the Label was a direct
# child. Driven by the Label's own minimum_size_changed, so "7" -> "13" resizes the slot
# without update_intent() having to remember to.
func _sync_label_slot() -> void:
    var wanted: float = maxf(label.get_combined_minimum_size().x, label.custom_minimum_size.x)
    label_slot.custom_minimum_size = Vector2(wanted, ROW_HEIGHT)
    label.size = Vector2(wanted, ROW_HEIGHT)


func update_intent(intent: Intent) -> void:
    if not intent:
        hide()
        return

    icon.texture = intent.icon
    icon.visible = icon.texture != null
    label.text = str(intent.current_text)
    label.visible = intent.current_text.length() > 0
    show()


# Floats between half a bob above and half below the laid-out spot, so the telegraph's
# average position is still exactly where the layout put it. Icon and number ride the SAME
# Tween as parallel steps rather than two tweens with matching numbers - that way they
# cannot drift apart by a frame no matter what else is going on.
func _start_bob() -> void:
    if _bob_tween and _bob_tween.is_valid():
        _bob_tween.kill()
    var high := -BOB_DISTANCE * 0.5
    var low := BOB_DISTANCE * 0.5
    icon.position.y = low
    label.position.y = low
    # .from() on every leg: a Tween samples the live property when it first PROCESSES, not
    # when it's built, so without pinning the ends a tween created in the same frame another
    # was killed can capture a stale value and animate flat.
    _bob_tween = create_tween().set_loops()
    _bob_tween.tween_property(icon, "position:y", high, _bob_half) \
            .from(low).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(label, "position:y", high, _bob_half) \
            .from(low).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.tween_property(icon, "position:y", low, _bob_half) \
            .from(high).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(label, "position:y", low, _bob_half) \
            .from(high).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _get_tooltip_text_for_icon() -> String:
    if not icon.texture:
        return ""
    var icon_name = icon.texture.resource_path.get_file().get_basename().to_lower()
    match icon_name:
        "attack_icon_intent":
            return "This enemy will attack you."
        "shield", "block_icon_intent":
            return "This enemy will block damage next turn."
        "debuff_icon_3":
            return "This enemy will inflict a negative effect to you."
        "debuff_icon":
            return "This enemy will inflict a negative effect to you."
        "debuff_intent":
            return "This enemy will inflict a negative effect to you."
        "buff_icon_intent":
            return "This enemy will gain a positive effect."
        "buff_icon":
            return "This enemy will gain a positive effect."
        "buff_block_intent":
            return "This enemy will gain a positive effect and block damage next turn."
        _:
            return "This enemy is preparing something."

func _on_mouse_entered() -> void:
    # Free any tooltip still hanging around from a previous hover before making a new one -
    # otherwise the old instance gets silently overwritten below without ever being freed,
    # leaking it on screen (see the safety-timeout fix below for why that leak was permanent).
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null

    await get_tree().create_timer(0.01).timeout
    if not get_global_rect().has_point(get_global_mouse_position()):
        return
    var text = _get_tooltip_text_for_icon()
    if text == "":
        return

    tooltip_instance = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance)
    var tooltip_panel = tooltip_instance.get_node("Tooltip")
    tooltip_panel.get_node("%TooltipText").text = text
    tooltip_panel.show_tooltip(global_position + Vector2(-40, -80))

    _start_tooltip_safety_timeout(tooltip_instance)

func _start_tooltip_safety_timeout(this_tooltip) -> void:
    await get_tree().create_timer(8.0).timeout
    if not is_instance_valid(this_tooltip):
        return
    # Always free THIS specific instance once its time is up, even if a newer tooltip has
    # since replaced it in `tooltip_instance` - the old check (`tooltip_instance == this_tooltip`)
    # meant a superseded tooltip could never match anymore and would never get freed by its own
    # timeout, i.e. it would sit on screen permanently. That's exactly the "stuck forever" bug.
    if tooltip_instance == this_tooltip:
        tooltip_instance = null
    this_tooltip.queue_free()

func _on_mouse_exited() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
