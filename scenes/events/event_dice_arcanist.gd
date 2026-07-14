extends Control
@export var treasure_relic_pool: RelicPool  # Changed from Array[Relic] to RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats
@onready var animation_player: AnimationPlayer = %AnimationPlayer
var found_relic: Relic

var character_stats: CharacterStats
var run_stats: RunStats

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
const TOOLTIP_HEIGHT = 108
const TOOLTIP_WIDTH = 204
const TOOLTIP_SPACING = 4
const TOOLTIP_OFFSET_X = 20
const GIVE_COLOR = "e05a5a"
const GET_COLOR = "5ad16b"
const DICE_CHIP := preload("res://relics/dice_chip.tres")

@onready var trade_relic_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeRelic

var _tooltip_instances: Array = []
var _hover_id := 0

func _ready() -> void:
    trade_relic_button.mouse_entered.connect(_on_trade_relic_mouse_entered)
    trade_relic_button.mouse_exited.connect(_on_trade_relic_mouse_exited)

# Tooltips are added under get_tree().root (not this node) - same leak-prone
# pattern documented on relic_ui.gd/fickle_broker.gd, cleaned up explicitly if
# this event scene leaves the tree while still hovering.
func _exit_tree() -> void:
    _cleanup_tooltips()

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func generate_relic() -> void:
    found_relic = treasure_relic_pool.get_random_relic(char_stats, relic_handler)

func _on_gain_relic_pressed() -> void:
    generate_relic()
    if found_relic && Global.gold >=50 :
        Events.show_reward_with_relic.emit(found_relic)
        Global.gold -= 50
        Events.gold_changed.emit()


func _on_buy_relic_blood_pressed() -> void:
    generate_relic()
    if found_relic :
        character_stats.health-=8
        Events.hp_changed.emit()
        Events.show_reward_with_relic.emit(found_relic)



func _on_quit_pressed() -> void:
    Events.event_exited.emit()


func _on_get_relic_pressed() -> void:
    generate_relic()
    if found_relic :
        character_stats.health-=8
        Events.hp_changed.emit()
        Events.show_reward_with_relic.emit(found_relic)


func _on_get_heal_pressed() -> void:
        character_stats.health+=16
        Events.hp_changed.emit()
        var campfire_heal_sound = preload("res://sounds/fountainheal.wav")
        SFXPlayer.play(campfire_heal_sound)
        Events.event_exited.emit()


func _on_trade_relic_pressed() -> void:
    # Remove the Dice Bag (coupons.tres)
    for relic_ui in relic_handler._get_all_relic_ui_nodes():
        if relic_ui.relic.id == "blue_dice":
            relic_ui.queue_free()
            break

    # Give Dice Chip
    var dice_chip := load("res://relics/dice_chip.tres") as Relic
    if dice_chip == null:
        push_error("dice_chip.tres not found")
        return
    relic_handler.add_relic(dice_chip)

    Events.event_exited.emit()


# Shows two stacked tooltips on hover: the relic you'd give up (Dice Bag, red)
# and the relic you'd get (Dice Chip, green) - same give/get pattern as
# event_fickle_broker.gd, so the trade isn't a leap of faith by name alone.
func _on_trade_relic_mouse_entered() -> void:
    _hover_id += 1
    var my_id := _hover_id
    _cleanup_tooltips()

    var give_relic: Relic = null
    for relic_ui in relic_handler._get_all_relic_ui_nodes():
        if relic_ui.relic and relic_ui.relic.id == "blue_dice":
            give_relic = relic_ui.relic
            break

    var entries := []
    if give_relic:
        entries.append({"label": "Give: ", "color": GIVE_COLOR, "relic": give_relic})
    entries.append({"label": "Get: ", "color": GET_COLOR, "relic": DICE_CHIP})

    var total_height := (entries.size() * TOOLTIP_HEIGHT) + ((entries.size() - 1) * TOOLTIP_SPACING)
    var screen_height := get_viewport_rect().size.y
    var start_y := trade_relic_button.global_position.y + (trade_relic_button.size.y / 2.0) - (total_height / 2.0)
    if start_y + total_height > screen_height - 20:
        start_y = screen_height - total_height - 20
    if start_y < 20:
        start_y = 20

    var screen_width := get_viewport_rect().size.x
    var base_x := trade_relic_button.global_position.x + trade_relic_button.size.x + TOOLTIP_OFFSET_X
    if base_x + TOOLTIP_WIDTH > screen_width - 20:
        base_x = trade_relic_button.global_position.x - TOOLTIP_OFFSET_X - TOOLTIP_WIDTH
    base_x = clamp(base_x, 20, screen_width - TOOLTIP_WIDTH - 20)

    for i in entries.size():
        var entry: Dictionary = entries[i]
        var relic: Relic = entry["relic"]
        var tooltip := TooltipScene.instantiate()
        get_tree().root.add_child(tooltip)
        var panel = tooltip.get_node("Tooltip")
        panel.tooltip_title.text = "[color=#%s][b]%s%s[/b][/color]" % [entry["color"], entry["label"], relic.relic_name]
        # See relic_ui.gd's _fit_tooltip_title - the title box is fixed-width and doesn't
        # grow to fit, so a long name (plus the label prefix here) can get clipped.
        var full_title_len: int = entry["label"].length() + relic.relic_name.length()
        if full_title_len > 20:
            panel.tooltip_title.add_theme_font_size_override("bold_font_size", 11)
        elif full_title_len > 15:
            panel.tooltip_title.add_theme_font_size_override("bold_font_size", 13)
        panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)
        var pos := Vector2(base_x, start_y + i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))
        panel.show_tooltip(pos)
        _tooltip_instances.append(tooltip)

    var captured_id := my_id
    get_tree().create_timer(8.0).timeout.connect(func():
        if captured_id == _hover_id:
            _cleanup_tooltips()
    )


func _on_trade_relic_mouse_exited() -> void:
    _hover_id += 1
    _cleanup_tooltips()


func _cleanup_tooltips() -> void:
    for tooltip in _tooltip_instances:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    _tooltip_instances.clear()
