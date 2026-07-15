class_name ShopCard
extends VBoxContainer

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

@export var card: Card : set = set_card

@onready var card_container: CenterContainer = $CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: RichTextLabel = %PriceLabel
@onready var buy_button: Button = %BuyButton
var gold_cost: int = 0

# Priced by rarity_tier instead of a single flat randi_range(30, 80) for every card - sits
# under relics (120-170) even at Rare so cards never feel like the "safe" gold sink.
const PRICE_RANGE_COMMON := Vector2i(40, 55)
const PRICE_RANGE_UNCOMMON := Vector2i(60, 80)
const PRICE_RANGE_RARE := Vector2i(95, 125)

#func _ready() -> void:
    #update()

func update(run_stats: RunStats) -> void:
    if not card_container or not price or not buy_button:
        return
    price_label.text = "[center]Buy ([color=#FFD700]" + str(gold_cost) + "G[/color])[/center]"
    if Global.gold >= gold_cost:
        buy_button.disabled = false
    else:
        buy_button.disabled = true

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


func _on_buy_button_pressed() -> void:
    Events.shop_card_bought.emit(card, gold_cost)
    SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
    card_container.queue_free()
    price.queue_free()
    buy_button.queue_free()
