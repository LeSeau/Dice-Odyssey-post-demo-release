class_name CharacterStats
extends Stats

@export var starting_deck: CardPile
@export var cards_per_turn: int
@export var max_mana: int
@export var draftable_cards: CardPile
@export var starting_relic: Relic

var mana: int : set = set_mana
var deck: CardPile
var discard: CardPile
var draw_pile: CardPile
var exhaust: CardPile


func _ready() -> void:
    Events.event_damage.connect(_on_event_damage)



func set_mana(value: int) -> void:
    mana = value
    stats_changed.emit()


func reset_mana() -> void:
    self.mana = max_mana


func take_damage(damage: int) -> void:
    var initial_health := health
    super.take_damage(damage)
    if initial_health > health:
        Events.player_hit.emit()
    print("health", health)


func can_play_card(card: Card) -> bool:
    return true


func create_instance() -> Resource:
    var instance: CharacterStats = self.duplicate()
    instance.health = max_health
    Global.player_hp = max_health
    instance.block = 0
    instance.reset_mana()
    instance.deck = instance.starting_deck.duplicate()
    instance.draw_pile = CardPile.new()
    instance.discard = CardPile.new()
    instance.exhaust = CardPile.new()
    return instance

func _on_event_damage(amount):
    print("taking damage from event")
    health-=10
    Global.player_hp = health
