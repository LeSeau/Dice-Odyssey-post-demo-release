extends Control

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
const TOOLTIP_HEIGHT = 108
const TOOLTIP_WIDTH = 204
const TOOLTIP_SPACING = 4
const TOOLTIP_OFFSET_X = 20
const GIVE_COLOR = "e05a5a"
const GET_COLOR = "5ad16b"

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

var _trade_a_give: RelicUI
var _trade_a_get: Relic
var _trade_b_give: RelicUI
var _trade_b_get: Relic

var _tooltip_instances: Array = []
var _hover_id := 0

@onready var trade_a_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeA
@onready var trade_a_label: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeA/RichTextLabel
@onready var trade_b_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeB
@onready var trade_b_label: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeB/RichTextLabel

func _ready() -> void:
    trade_a_button.mouse_entered.connect(_on_trade_button_mouse_entered.bind(trade_a_button))
    trade_a_button.mouse_exited.connect(_on_trade_button_mouse_exited)
    trade_b_button.mouse_entered.connect(_on_trade_button_mouse_entered.bind(trade_b_button))
    trade_b_button.mouse_exited.connect(_on_trade_button_mouse_exited)

# Tooltips are added under get_tree().root (not this node), same leak-prone pattern
# documented on relic_ui.gd/card_menu_ui.gd - explicitly clean up when this event
# scene itself leaves the tree (e.g. a trade is confirmed while still hovering).
func _exit_tree() -> void:
    _cleanup_tooltips()

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats
    _build_trade_offers()


# Two concrete, fully-visible trade proposals instead of one blind swap - each
# names exactly which Relic you'd give up and which you'd get, so the choice is
# an actual decision rather than a coin flip. relic_handler/treasure_relic_pool
# are assigned by run.gd before setup() runs (see its event-dispatch block), so
# they're safe to use here.
func _build_trade_offers() -> void:
    var owned := relic_handler._get_all_relic_ui_nodes()
    if owned.is_empty():
        trade_a_button.hide()
        trade_b_button.hide()
        return
    owned.shuffle()

    _trade_a_give = owned[0]
    _trade_a_get = treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if _trade_a_get:
        trade_a_label.text = "[center]Trade [color=red]%s[/color] for [color=green]%s[/color][/center]" % [_trade_a_give.relic.relic_name, _trade_a_get.relic_name]
    else:
        trade_a_button.hide()

    # give varies automatically (distinct shuffled indices) whenever the player owns
    # more than 1 relic, and reusing owned[0] when they only own 1 is unavoidable -
    # exactly the "okay to repeat the give side only if there's no other relic to
    # give" rule. get is excluded explicitly since nothing else stops both trades
    # from independently rolling the same reward relic.
    _trade_b_give = owned[1] if owned.size() > 1 else owned[0]
    var get_exclude: Array[Relic] = []
    if _trade_a_get:
        get_exclude.append(_trade_a_get)
    _trade_b_get = treasure_relic_pool.get_random_relic(char_stats, relic_handler, get_exclude)
    if _trade_b_get:
        trade_b_label.text = "[center]Trade [color=red]%s[/color] for [color=green]%s[/color][/center]" % [_trade_b_give.relic.relic_name, _trade_b_get.relic_name]
    else:
        trade_b_button.hide()


func _on_trade_a_pressed() -> void:
    if not is_instance_valid(_trade_a_give) or not _trade_a_get:
        Events.event_exited.emit()
        return
    _trade_a_give.queue_free()
    Events.show_reward_with_relic.emit(_trade_a_get)


func _on_trade_b_pressed() -> void:
    if not is_instance_valid(_trade_b_give) or not _trade_b_get:
        Events.event_exited.emit()
        return
    _trade_b_give.queue_free()
    Events.show_reward_with_relic.emit(_trade_b_get)


func _on_leave_pressed() -> void:
    Events.event_exited.emit()


# Shows two stacked tooltips for the hovered trade button: the relic you'd give up
# (red, matching the button label's coloring) and the relic you'd get (green) -
# so the player can actually evaluate the trade instead of judging it by name alone.
func _on_trade_button_mouse_entered(button: Button) -> void:
    _hover_id += 1
    var my_id := _hover_id
    _cleanup_tooltips()

    var give: RelicUI = _trade_a_give if button == trade_a_button else _trade_b_give
    var get_relic: Relic = _trade_a_get if button == trade_a_button else _trade_b_get
    if not is_instance_valid(give) or not give.relic or not get_relic:
        return

    var entries := [
        {"label": "Give: ", "color": GIVE_COLOR, "relic": give.relic},
        {"label": "Get: ", "color": GET_COLOR, "relic": get_relic},
    ]

    var total_height := (entries.size() * TOOLTIP_HEIGHT) + ((entries.size() - 1) * TOOLTIP_SPACING)
    var screen_height := get_viewport_rect().size.y
    var start_y := button.global_position.y + (button.size.y / 2.0) - (total_height / 2.0)
    if start_y + total_height > screen_height - 20:
        start_y = screen_height - total_height - 20
    if start_y < 20:
        start_y = 20

    # These trade buttons stretch nearly full-width, so "right of the button" (the
    # convention used elsewhere, e.g. relic_ui.gd's tag tooltips) runs straight off
    # the right edge of the screen - flip to the button's left when there isn't
    # room, then hard-clamp so it's never off-screen on either side.
    var screen_width := get_viewport_rect().size.x
    var base_x := button.global_position.x + button.size.x + TOOLTIP_OFFSET_X
    if base_x + TOOLTIP_WIDTH > screen_width - 20:
        base_x = button.global_position.x - TOOLTIP_OFFSET_X - TOOLTIP_WIDTH
    base_x = clamp(base_x, 20, screen_width - TOOLTIP_WIDTH - 20)

    for i in entries.size():
        var entry: Dictionary = entries[i]
        var relic: Relic = entry["relic"]
        var tooltip := TooltipScene.instantiate()
        get_tree().root.add_child(tooltip)
        var panel = tooltip.get_node("Tooltip")
        panel.tooltip_title.text = "[color=#%s][b]%s%s[/b][/color]" % [entry["color"], entry["label"], relic.relic_name]
        panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)
        var pos := Vector2(base_x, start_y + i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))
        panel.show_tooltip(pos)
        _tooltip_instances.append(tooltip)

    var captured_id := my_id
    get_tree().create_timer(8.0).timeout.connect(func():
        if captured_id == _hover_id:
            _cleanup_tooltips()
    )


func _on_trade_button_mouse_exited() -> void:
    _hover_id += 1
    _cleanup_tooltips()


func _cleanup_tooltips() -> void:
    for tooltip in _tooltip_instances:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    _tooltip_instances.clear()
