extends Control

# Same dice tooltip the shops and the combat dice panel use, so hovering "accept the wager"
# tells you what an Evil Dice actually rolls (6/6/6/0) before you pay 16 Max HP for one.
# It's infusion-aware for free: if this run already infused Evil, the panel renames itself
# to Repented and appends the infusion line (see dice_tooltip.gd::get_tooltip_content).
const DiceTooltipScene = preload("res://scenes/ui/dice_tooltip.tscn")
const TOOLTIP_WIDTH := 204.0
# Panel floor is 88 (dice_tooltip.tscn); an infused die grows it by a line, so clamp with
# headroom rather than letting the bottom edge slip off-screen.
const TOOLTIP_HEIGHT := 110.0
const TOOLTIP_OFFSET_X := 20.0
const SCREEN_MARGIN := 20.0

var character_stats: CharacterStats
var run_stats: RunStats

var _dice_tooltip: CanvasLayer
var _hover_id := 0

@onready var accept_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Accept

# The eclipse's tribute is paid in permanent Max HP now (was 2 random relics). Relics
# cost near-nothing early-run when you own few/none, which made accepting a no-brainer
# every time; Max HP always bites, so the wager is a real decision at any point in the run.
const WAGER_MAX_HP_COST := 16
const DECLINE_HP_COST := 6


func _ready() -> void:
    accept_button.mouse_entered.connect(_on_accept_mouse_entered)
    accept_button.mouse_exited.connect(_on_accept_mouse_exited)


# The tooltip is parented to get_tree().root, not to this node, so nothing frees it when the
# event closes mid-hover (accepting the wager does exactly that) - same leak documented on
# relic_ui.gd/event_fickle_broker.gd.
func _exit_tree() -> void:
    _cleanup_tooltip()


func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_accept_mouse_entered() -> void:
    _hover_id += 1
    var my_id := _hover_id
    _cleanup_tooltip()
    _dice_tooltip = DiceTooltipScene.instantiate()
    Global.add_tooltip(_dice_tooltip, self)
    var panel = _dice_tooltip.get_node("DiceTooltip")
    panel.get_tooltip_content("evil")
    panel.show_tooltip(_tooltip_position())
    # Safety net: mouse_exited never fires if the button is freed or the tree pauses while
    # hovered (see intent_ui.gd's timeout for the same reason).
    get_tree().create_timer(8.0).timeout.connect(func():
        if my_id == _hover_id:
            _cleanup_tooltip()
    )


func _on_accept_mouse_exited() -> void:
    _hover_id += 1
    _cleanup_tooltip()


# These option buttons are wide, so the usual "to the right of it" placement runs off-screen -
# flip to the button's left when there's no room, then hard-clamp both axes.
func _tooltip_position() -> Vector2:
    var screen := get_viewport_rect().size
    var x := accept_button.global_position.x + accept_button.size.x + TOOLTIP_OFFSET_X
    if x + TOOLTIP_WIDTH > screen.x - SCREEN_MARGIN:
        x = accept_button.global_position.x - TOOLTIP_OFFSET_X - TOOLTIP_WIDTH
    x = clampf(x, SCREEN_MARGIN, screen.x - TOOLTIP_WIDTH - SCREEN_MARGIN)
    var y := accept_button.global_position.y + (accept_button.size.y / 2.0) - (TOOLTIP_HEIGHT / 2.0)
    y = clampf(y, SCREEN_MARGIN, screen.y - TOOLTIP_HEIGHT - SCREEN_MARGIN)
    return Vector2(x, y)


func _cleanup_tooltip() -> void:
    if _dice_tooltip and is_instance_valid(_dice_tooltip):
        _dice_tooltip.queue_free()
    _dice_tooltip = null


# Pay WAGER_MAX_HP_COST permanent Max HP for a guaranteed Evil Dice. Dice gained from
# events deliberately do NOT touch purchased_dice_counts, so this never escalates the
# dice-shop price (only gold purchases at the two shops do - see
# global.gd::current_dice_price). The Max HP write mirrors event_patient_monk.gd's
# pattern in reverse: Global.player_max_hp is kept in lockstep (the top bar reads it,
# not max_health directly).
func _on_accept_pressed() -> void:
    character_stats.max_health -= WAGER_MAX_HP_COST
    Global.player_max_hp -= WAGER_MAX_HP_COST
    # Re-clamp current health through its setter (clamps to the new, lower max and syncs
    # Global.player_hp). Max HP loss never kills on its own - current HP is separate.
    character_stats.health = mini(character_stats.health, character_stats.max_health)
    Events.hp_changed.emit()

    Global.evil_dice_max_amount += 1
    Global.evil_dice_current_amount += 1
    if Global.evil_dice_max_amount == 1:
        Global.dice_inventory.append("evil")
    Events.dice_bought.emit("evil")
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
    Events.event_exited.emit()


func _on_decline_pressed() -> void:
    character_stats.health -= DECLINE_HP_COST
    Events.hp_changed.emit()
    Events.event_exited.emit()
