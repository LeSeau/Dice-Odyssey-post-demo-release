class_name Shop
extends Control

const SHOP_CARD = preload("res://scenes/shop/shop_card.tscn")
const SHOP_RELIC = preload("res://scenes/shop/shop_relic.tscn")

@export var shop_relic_pool: RelicPool
@export var char_stats: CharacterStats
@export var run_stats: RunStats
@export var relic_handler: RelicHandler

@onready var cards: HBoxContainer = %Cards
@onready var relics: HBoxContainer = %Relics

func _ready() -> void:
    for shop_card: ShopCard in cards.get_children():
        shop_card.queue_free()
    
    for shop_relic: ShopRelic in relics.get_children():
        shop_relic.queue_free()
    
    Events.shop_card_bought.connect(_on_shop_card_bought)
    Events.shop_relic_bought.connect(_on_shop_relic_bought)

func populate_shop() -> void:
    _generate_shop_cards()
    _generate_shop_relics()
    
# Guaranteed composition (2 Common / 2 Uncommon / 1 Rare) rather than a blind shuffle - every
# shop visit now contains exactly one expensive temptation instead of the old pure-random slice
# sometimes offering zero Rares (or, before rarity existed at all, zero of anything special).
const SHOP_COMPOSITION: Array[Card.RarityTier] = [
    Card.RarityTier.COMMON, Card.RarityTier.COMMON,
    Card.RarityTier.UNCOMMON, Card.RarityTier.UNCOMMON,
    Card.RarityTier.RARE,
]


func _generate_shop_cards() -> void:
    var shop_card_array: Array[Card] = []
    var available_cards: Array[Card] = char_stats.draftable_cards.cards.duplicate(true)
    var owned_cards: Array[Card] = char_stats.deck.cards

    for tier: Card.RarityTier in SHOP_COMPOSITION:
        var picked_card := CardRarityDraw.pick_card(available_cards, tier, owned_cards)
        if picked_card:
            available_cards.erase(picked_card)
            shop_card_array.append(picked_card)

    for card: Card in shop_card_array:
        var new_shop_card := SHOP_CARD.instantiate() as ShopCard
        cards.add_child(new_shop_card)
        new_shop_card.card = card
        new_shop_card.update(run_stats)
        

func _generate_shop_relics() -> void:
    var shop_relics_array: Array[Relic] = []
    var available_relics := shop_relic_pool.pool.filter(
        func(relic: Relic):
            var can_appear := relic.can_appear_as_reward(char_stats)
            var already_had_it := relic_handler.has_relic(relic.id)
            return can_appear and not already_had_it
    )

    available_relics.shuffle()
    shop_relics_array = available_relics.slice(0, 3)
    
    for relic: Relic in shop_relics_array:
        var new_shop_relic := SHOP_RELIC.instantiate() as ShopRelic
        relics.add_child(new_shop_relic)
        new_shop_relic.relic = relic
        new_shop_relic.update(run_stats)


func _update_items() -> void:
    for shop_card: ShopCard in cards.get_children():
        shop_card.update(run_stats)
        
        
    for shop_relic: ShopRelic in relics.get_children():
            shop_relic.update(run_stats)


func _on_back_button_pressed() -> void:
    Events.shop_exited.emit()


func _on_shop_card_bought(card: Card, gold_cost: int) -> void:
    char_stats.deck.add_card(card)
    Global.gold -= gold_cost
    _update_items()
    Events.gold_changed.emit()


func _on_shop_relic_bought(relic: Relic, gold_cost: int) -> void:
    relic_handler.add_relic(relic)
    Global.gold -= gold_cost
    _update_items() 
    Events.gold_changed.emit()


func _on_button_pressed() -> void:
    Events.shop_exited.emit()
