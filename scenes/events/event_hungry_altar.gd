extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

const GOLD_FALLBACK := 40

@onready var offer_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Offer

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# The reward only fires once a card has actually been sacrificed (Events.card_removed,
# emitted by CardMenuUI right after the removal animation - see run.gd's own
# _on_card_removed for the same signal). Connected one-shot only at the moment the
# player commits, not in _ready(), so this can never react to an unrelated removal
# elsewhere. Leave stays visible throughout - backing out of the deck view without
# removing anything (its own Back button) leaves this screen exactly as it was.
func _on_offer_pressed() -> void:
    offer_button.hide()
    Events.card_removed.connect(_on_card_sacrificed, CONNECT_ONE_SHOT)
    Events.open_deck_view.emit()


func _on_card_sacrificed(_card) -> void:
    var relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if relic:
        Events.show_reward_with_relic.emit(relic)
    else:
        Global.gold += GOLD_FALLBACK
        Events.gold_changed.emit()
        Events.event_exited.emit()


func _on_leave_pressed() -> void:
    Events.event_exited.emit()
