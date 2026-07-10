extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

var _trade_a_give: RelicUI
var _trade_a_get: Relic
var _trade_b_give: RelicUI
var _trade_b_get: Relic

@onready var trade_a_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeA
@onready var trade_a_label: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeA/RichTextLabel
@onready var trade_b_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeB
@onready var trade_b_label: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/TradeB/RichTextLabel

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

    _trade_b_give = owned[1] if owned.size() > 1 else owned[0]
    _trade_b_get = treasure_relic_pool.get_random_relic(char_stats, relic_handler)
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
