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
    if found_relic && Global.gold >=50 :
        Events.show_reward_with_relic.emit(found_relic)
        Global.gold -= 50
        Events.gold_changed.emit()


func _on_buy_relic_blood_pressed() -> void:
    generate_relic()
    if found_relic :
        character_stats.health-=8
        Events.hp_changed.emit()
        Events.show_reward_with_relic.emit(found_relic)
        


func _on_quit_pressed() -> void:
    Events.event_exited.emit()


func _on_get_relic_pressed() -> void:
    generate_relic()
    if found_relic :
        character_stats.health-=8
        Events.hp_changed.emit()
        Events.show_reward_with_relic.emit(found_relic)


func _on_get_heal_pressed() -> void:
        character_stats.health+=16
        Events.hp_changed.emit()
        var campfire_heal_sound = preload("res://sounds/fountainheal.wav")
        SFXPlayer.play(campfire_heal_sound)
        Events.event_exited.emit()


func _on_trade_relic_pressed() -> void:
    # Remove the Dice Bag (coupons.tres)
    for relic_ui in relic_handler._get_all_relic_ui_nodes():
        if relic_ui.relic.id == "blue_dice":
            relic_ui.queue_free()
            break
    
    # Give Dice Chip
    var dice_chip := load("res://relics/dice_chip.tres") as Relic
    if dice_chip == null:
        push_error("dice_chip.tres not found")
        return
    relic_handler.add_relic(dice_chip)
    
    Events.event_exited.emit()
