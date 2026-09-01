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
@onready var icon2_slot: Control = $IconSlot2
@onready var icon2: TextureRect = $IconSlot2/Icon2
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
    # STS2-style rider: a combo intent shows a second full-size icon instead of one merged
    # artwork. Row order is NUMBER FIRST, then the icons ("8 [sword][skull]" - Julien,
    # 2026-08-14): the amount anchors the left edge and every icon groups after it, so the
    # number never gets sandwiched between two glyphs. Hiding the SLOT - not just the
    # TextureRect - removes it from the HBox layout entirely, so single-icon intents keep
    # their exact old footprint; the root grows symmetrically (grow_horizontal = both) so
    # the telegraph stays centred above the head either way.
    icon2.texture = intent.icon2
    icon2_slot.visible = intent.icon2 != null
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
    icon2.position.y = low
    label.position.y = low
    # .from() on every leg: a Tween samples the live property when it first PROCESSES, not
    # when it's built, so without pinning the ends a tween created in the same frame another
    # was killed can capture a stale value and animate flat.
    # icon2 rides the SAME tween as one more parallel step (even while hidden - harmless),
    # so a combo intent's rider can never drift a frame apart from its siblings.
    _bob_tween = create_tween().set_loops()
    _bob_tween.tween_property(icon, "position:y", high, _bob_half) \
            .from(low).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(label, "position:y", high, _bob_half) \
            .from(low).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(icon2, "position:y", high, _bob_half) \
            .from(low).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.tween_property(icon, "position:y", low, _bob_half) \
            .from(high).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(label, "position:y", low, _bob_half) \
            .from(high).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.parallel().tween_property(icon2, "position:y", low, _bob_half) \
            .from(high).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _get_tooltip_text_for_icon() -> String:
    if not icon.texture:
        return ""
    var text := _tooltip_text_for_texture(icon.texture)
    if icon2_slot.visible and icon2.texture:
        var rider := _rider_tooltip_text_for_texture(icon2.texture)
        if rider != "":
            text += " " + rider
    return text


func _tooltip_text_for_texture(texture: Texture2D) -> String:
    var icon_name = texture.resource_path.get_file().get_basename().to_lower()
    match icon_name:
        "attack_icon_intent":
            return "This enemy will attack you."
        "shield", "block_icon_intent":
            return "This enemy will block damage next turn."
        "debuff_icon_3":
            return "This enemy will inflict a negative effect on you."
        "debuff_icon":
            return "This enemy will inflict a negative effect on you."
        "debuff_intent":
            return "This enemy will inflict a negative effect on you."
        "dice_debuff_intent":
            return "This enemy will tamper with your Dice."
        "junk_card_intent":
            return "This enemy will put a bad card into your deck."
        "buff_icon_intent":
            return "This enemy will gain a positive effect."
        "buff_icon":
            return "This enemy will gain a positive effect."
        "buff_block_intent":
            return "This enemy will gain a positive effect and block damage next turn."
        _:
            return "This enemy is preparing something."


# Second sentence for the rider icon of a combo intent, phrased as a follow-up so the pair
# reads as one plan ("This enemy will attack you. It will also inflict a negative effect
# on you."). Same basename-matching rule as above: any NEW icon filename needs a case here
# too, or the rider silently contributes nothing to the tooltip.
func _rider_tooltip_text_for_texture(texture: Texture2D) -> String:
    var icon_name = texture.resource_path.get_file().get_basename().to_lower()
    match icon_name:
        "attack_icon_intent":
            return "It will also attack you."
        "shield", "block_icon_intent":
            return "It will also block damage next turn."
        "debuff_icon_3", "debuff_icon", "debuff_intent":
            return "It will also inflict a negative effect on you."
        "dice_debuff_intent":
            return "It will also tamper with your Dice."
        "junk_card_intent":
            return "It will also put a bad card into your deck."
        "buff_icon_intent", "buff_icon":
            return "It will also gain a positive effect."
        "buff_block_intent":
            return "It will also gain a positive effect and block damage next turn."
        _:
            return ""

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
    Global.add_tooltip(tooltip_instance, self)
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


# The reported "This enemy will attack you" popup that never went away (2026-08-03): kill the
# enemy while its intent is hovered and this node is freed mid-hover, so mouse_exited never
# fires. The 8s timeout above cannot save it either - that's a coroutine owned by THIS node,
# so it dies with it, silently, leaving a tooltip parented to the tree root with nothing left
# alive that knows about it. It then survived into the map, the shop and the next fight,
# sitting on top of the enemy row. Global.add_tooltip() registers the tooltip against this
# node so the central sweep catches it too; this is the immediate, same-frame cleanup.
func _exit_tree() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
