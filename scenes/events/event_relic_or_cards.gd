extends Control
@export var treasure_relic_pool: RelicPool  # Changed from Array[Relic] to RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats
@onready var animation_player: AnimationPlayer = %AnimationPlayer
var found_relic: Relic

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func generate_relic() -> void:
    found_relic = treasure_relic_pool.get_random_relic(char_stats, relic_handler)

func _on_gain_relic_pressed() -> void:
    generate_relic()
    if found_relic :
        Events.show_reward_with_relic.emit(found_relic)


func _on_buy_relic_blood_pressed() -> void:
    generate_relic()
    if found_relic :
        character_stats.health-=8
        Events.hp_changed.emit()
        Events.show_reward_with_relic.emit(found_relic)
        


func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_get_2_cards_pressed() -> void:
    Global.pending_card_rewards = 2
    Events.show_reward.emit()
