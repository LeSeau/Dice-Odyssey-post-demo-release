class_name ShopRelic
extends VBoxContainer

const RELIC_UI = preload("res://scenes/relic_handler/relic_ui.tscn")

@export var relic: Relic : set = set_relic

@onready var relic_container: CenterContainer = $RelicVisual/RelicContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
# Priced by rarity since 2026-08-23. The old flat 85-120 band replaced an even older 120-170
# one, because at that price a relic sat next to a 150-270 die while being a much smaller
# power spike, leaving the relic slots as dead inventory at the moment of decision. The bands
# below keep that ceiling intact - the top of Rare (160) is still clearly under any die - and
# straddle the old band rather than inflating past it.
const PRICE_BY_RARITY := {
	Relic.RarityTier.COMMON: [70, 95],
	Relic.RarityTier.UNCOMMON: [95, 125],
	Relic.RarityTier.RARE: [125, 160],
}

# Assigned in set_relic once the rarity is known - an @onready would run before the relic is.
var gold_cost := 95
var _sold := false

# The relic icon is the click target now (STS-style). Kept so update() can dim it.
var _relic_ui: RelicUI = null

func update(run_stats: RunStats) -> void:
    if not relic_container or not price or _sold:
        return
    # STS-style price tag (coin sprite + amount, in the .tscn). The root scene is scaled
    # x3.2, so the coin/font are authored small (9px / 8px) to render ~29/26px.
    var affordable: bool = Global.gold >= gold_cost
    price_label.text = str(gold_cost)
    price_label.add_theme_color_override("font_color", Color("FFD700") if affordable else Color("FF4444"))
    if _relic_ui:
        _relic_ui.modulate = Color.WHITE if affordable else Color(0.55, 0.55, 0.55)

func set_relic(new_relic: Relic) -> void:
    if not is_node_ready():
        await ready

    relic = new_relic

    if relic != null:
        # Explicit Array: a Dictionary subscript is a Variant, and `:=` on it degrades what
        # the compiler knows well enough to break inference further down the file.
        var band: Array = PRICE_BY_RARITY.get(relic.rarity_tier,
                PRICE_BY_RARITY[Relic.RarityTier.COMMON])
        gold_cost = randi_range(band[0], band[1])

    for relic_ui: RelicUI in relic_container.get_children():
        relic_ui.queue_free()

    var new_relic_ui := RELIC_UI.instantiate() as RelicUI
    new_relic_ui.initialize_on_set = false
    relic_container.add_child(new_relic_ui)
    new_relic_ui.relic = relic
    _relic_ui = new_relic_ui
    # Click the relic itself to buy. The Icon/Counter children default to mouse_filter
    # STOP and fill the RelicUI, so they'd swallow the click before RelicUI's gui_input
    # sees it - make them click-through here (instance-local, doesn't touch combat relics).
    new_relic_ui.mouse_filter = Control.MOUSE_FILTER_STOP
    new_relic_ui.get_node("Icon").mouse_filter = Control.MOUSE_FILTER_IGNORE
    new_relic_ui.get_node("Counter").mouse_filter = Control.MOUSE_FILTER_IGNORE
    new_relic_ui.gui_input.connect(_on_relic_gui_input)


func _on_relic_gui_input(event: InputEvent) -> void:
    if _sold:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Global.gold < gold_cost:
            return
        _sold = true
        Events.shop_relic_bought.emit(relic, gold_cost)
        SFXPlayer.play(load("res://sounds/buydicesound.wav"))
        relic_container.queue_free()
        price.queue_free()
