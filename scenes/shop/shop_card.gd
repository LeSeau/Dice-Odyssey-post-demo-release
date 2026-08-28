class_name ShopCard
extends VBoxContainer

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

# Right-click opens the shared inspect overlay. Emitted rather than handled here because the
# overlay pages through every card still on offer, and only the shop knows what those are.
signal inspect_requested(card: Card)

@export var card: Card : set = set_card

@onready var card_container: CenterContainer = $CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
var gold_cost: int = 0
var _sold := false

# The card visual (CardMenuUI's Visuals) is the click target now (STS-style: click the
# item to buy, price is a passive label). Kept so update() can dim it when unaffordable.
var _card_menu_ui: CardMenuUI = null

# Priced by rarity_tier instead of a single flat randi_range(30, 80) for every card.
# 2026-07-23 retune: commons/uncommons trimmed so a card doesn't cost two fights of
# income; rares keep their sting. Value ladder: cards < relics (85-120) < dice (150-270+).
const PRICE_RANGE_COMMON := Vector2i(30, 45)
const PRICE_RANGE_UNCOMMON := Vector2i(50, 70)
const PRICE_RANGE_RARE := Vector2i(95, 125)

func update(run_stats: RunStats) -> void:
    if not card_container or not price or _sold:
        return
    # STS-style bare price tag: coin sprite (in the .tscn) + amount, gold when affordable
    # / red when not.
    var affordable: bool = Global.gold >= gold_cost
    price_label.text = str(gold_cost)
    price_label.add_theme_color_override("font_color", Color("FFD700") if affordable else Color("FF4444"))
    # Dim the whole card when you can't afford it (matches STS's greyed-out shop items).
    if _card_menu_ui:
        _card_menu_ui.modulate = Color.WHITE if affordable else Color(0.55, 0.55, 0.55)

func set_card(new_card: Card) -> void:
    if not is_node_ready():
        await ready
    card = new_card
    gold_cost = _price_for(card)

    for card_menu_ui: CardMenuUI in card_container.get_children():
        card_menu_ui.queue_free()

    var new_card_menu_ui := CARD_MENU_UI.instantiate() as CardMenuUI
    card_container.add_child(new_card_menu_ui)
    new_card_menu_ui.card = card
    _card_menu_ui = new_card_menu_ui
    # Click the card itself to buy (same Visuals gui_input the reward screen uses).
    new_card_menu_ui.get_node("Visuals").gui_input.connect(_on_card_gui_input)


func _price_for(for_card: Card) -> int:
    var range: Vector2i
    match for_card.rarity_tier:
        Card.RarityTier.RARE:
            range = PRICE_RANGE_RARE
        Card.RarityTier.UNCOMMON:
            range = PRICE_RANGE_UNCOMMON
        _:
            range = PRICE_RANGE_COMMON
    return randi_range(range.x, range.y)


func is_sold() -> bool:
    return _sold


func _on_card_gui_input(event: InputEvent) -> void:
    if _sold:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        inspect_requested.emit(card)
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Global.gold < gold_cost:
            return
        _sold = true
        Events.shop_card_bought.emit(card, gold_cost)
        SFXPlayer.play(load("res://sounds/buydicesound.wav"))
        # Freeze the slot's footprint BEFORE emptying it (Julien, 2026-07-31: "when i buy a
        # card in the shop, the other cards slightly move"). This VBox is sized by its card
        # (140 wide), but the scene's custom_minimum_size floor is only 120 - so once the
        # card and price are freed the slot snapped 20px narrower, and %Cards being a
        # SHRINK_CENTER HBox split that between the two sides: every other card slid 10px.
        # Pinning the combined min size leaves an empty gap exactly where the card was.
        custom_minimum_size = get_combined_minimum_size()
        card_container.queue_free()
        price.queue_free()
