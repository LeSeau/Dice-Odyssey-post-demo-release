class_name PlayerHandler
extends Node

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

@onready var hand: Control = $"../BattleUI/Hand"
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $"../AudioStreamPlayer2D"

@export var player: Player
@export var relics: RelicHandler


var character: CharacterStats


func _ready() -> void:
    Events.card_played.connect(_on_card_played)
    Events.block_reset.connect(_on_block_reset)
    Events.add_block.connect(_on_add_block)
    Events.draw_card.connect(_on_draw_card)
    Events.discard_random_card.connect(discard_random_card)


func start_battle(char_stats: CharacterStats) -> void:

    Global.fight_turn = 0
    Global.has_rolled_1_this_fight = false
    character = char_stats
    character.draw_pile = character.deck.duplicate(true)
    character.draw_pile.shuffle()
    if Global.tutorial_on:
        var forced_cards = [
            load("res://characters/warrior/cards/warrior_axe_attack1.tres"),
            load("res://characters/warrior/cards/warrior_block1.tres"),
            load("res://characters/warrior/cards/low_blow.tres"),
            load("res://characters/warrior/cards/warrior_axe_attack2.tres"),
            load("res://characters/warrior/cards/warrior_block2.tres")
        ]
        for forced_card in forced_cards:
            character.draw_pile.remove_card(forced_card)
        # Insert at front (will be drawn first)
        for i in range(forced_cards.size() - 1, -1, -1):
            character.draw_pile.cards.push_front(forced_cards[i])

    character.discard = CardPile.new()
    relics.relics_activated.connect(_on_relics_activated)
    player.status_handler.statuses_applied.connect(_on_statuses_applied)
    start_turn()


func start_turn() -> void:
    var forced_turn2_cards = [
        load("res://characters/warrior/cards/warrior_axe_attack3.tres"),
        load("res://characters/warrior/cards/card_recombobulate.tres"),
        load("res://characters/warrior/cards/warrior_block3.tres"),
        load("res://characters/warrior/cards/reinforce.tres"),
        load("res://characters/warrior/cards/warrior_axe_attack4.tres")
    ]

    Events.check_if_losing_strength.emit()
    character.block = 0
    Global.player.stats.block = 0
    Global.has_rolled_6_this_turn = false
    Global.cards_played_this_turn = 0

    character.reset_mana()
    relics.activate_relics_by_type(Relic.Type.START_OF_TURN)
    Global.blue_dice_current_amount = Global.blue_dice_max_amount + Global.blue_dice_bonus_amount + Global.blue_dice_bonus_amount_fight
    Global.roll_history = []
    if Global.tutorial_second_turn && Global.tutorial_on:
        for forced_card in forced_turn2_cards:
            character.draw_pile.remove_card(forced_card)

        for i in range(forced_turn2_cards.size() - 1, -1, -1):
            character.draw_pile.cards.push_front(forced_turn2_cards[i])
        Global.tutorial_second_turn = false
    Global.dice_amount_rolled_this_turn = 0
    Events.player_turn_started.emit()
    if Global.tutorial_end_turn: 
        Events.tutorial_step_requested.emit(12)
        Global.tutorial_end_turn = false

func end_turn() -> void:
    Events.clear_socket.emit()
    hand.disable_hand()
    Global.fight_turn+=1
    relics.activate_relics_by_type(Relic.Type.END_OF_TURN)



func draw_card() -> void:
    reshuffle_deck_from_discard()
    hand.add_card(character.draw_pile.draw_card())
    audio_stream_player_2d.stream = preload("res://drawcardsound.wav")
    audio_stream_player_2d.play()
    reshuffle_deck_from_discard()

func draw_cards(amount: int) -> void:
    # Load the audio file
    var draw_sound = preload("res://drawcardsound.wav")
    
    # Make sure the AudioStreamPlayer2D has the correct sound loaded
    audio_stream_player_2d.stream = draw_sound
    
    var tween := create_tween()
    for i in range(amount):
        tween.tween_callback(draw_card)
        tween.tween_callback(func(): audio_stream_player_2d.play())
        tween.tween_interval(HAND_DRAW_INTERVAL)
    
    tween.finished.connect(
        func(): Events.player_hand_drawn.emit()
    )

func discard_cards() -> void:
    print("trying to discard hand; bug?")
    
    # If hand is empty, emit signal immediately
    if hand.get_child_count() == 0:
        Events.player_hand_discarded.emit()
        print("hand was discarded (empty hand); bug?")
        return
        
    var tween := create_tween()
    for card_ui: CardUI in hand.get_children():
        tween.tween_callback(character.discard.add_card.bind(card_ui.card))
        tween.tween_callback(hand.discard_card.bind(card_ui))
        tween.tween_callback(func():
            audio_stream_player_2d.stream = preload("res://drawcardsound.wav")
            audio_stream_player_2d.play()
        )
        tween.tween_interval(HAND_DISCARD_INTERVAL)
    
    tween.finished.connect(func():
        Events.player_hand_discarded.emit()
        print("hand was discarded; bug?")
    )
    
func discard_random_card() -> void:
    var hand_cards := hand.get_children()
    if hand_cards.is_empty():
        return
    var random_index := randi() % hand_cards.size()
    var card_ui: CardUI = hand_cards[random_index]
    character.discard.add_card(card_ui.card)
    hand.discard_card(card_ui)
    audio_stream_player_2d.stream = preload("res://drawcardsound.wav")
    audio_stream_player_2d.play()



func reshuffle_deck_from_discard() -> void:
    if not character.draw_pile.empty():
        return

    while not character.discard.empty():
        character.draw_pile.add_card(character.discard.draw_card())

    character.draw_pile.shuffle()


func _on_card_played(card: Card) -> void:
    if card.exhausts:
        return
        
    character.discard.add_card(card)

func _on_statuses_applied(type: Status.Type) -> void:
    match type:
        Status.Type.START_OF_TURN:
            draw_cards(character.cards_per_turn)
        Status.Type.END_OF_TURN:
            discard_cards()
            
func _on_relics_activated(type: Relic.Type) -> void:
    match type:
        Relic.Type.START_OF_TURN:
            player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
        Relic.Type.END_OF_TURN:
            player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
            

func _on_block_reset():
    Global.player.stats.block = 0
    character.block=0
    
func _on_add_block(amount):
    character.block+=amount

func _on_draw_card(amount):
    var tween := create_tween()
    for i in range(amount):
        tween.tween_callback(draw_card)
        tween.tween_interval(HAND_DRAW_INTERVAL)
    
