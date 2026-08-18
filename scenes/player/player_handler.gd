class_name PlayerHandler
extends Node

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

# Forced opening hands for the 3 scripted tutorial turns (tutorial_redesign_2026-07.md
# §3/§6.B.3), keyed by Global.fight_turn at the moment _force_tutorial_hand() runs (0 = turn
# 1, 1 = turn 2, 2 = turn 3 - fight_turn increments in end_turn(), so start_turn() always
# sees the turn that's ABOUT to begin). cards_per_turn is 5, so every turn deals a normal
# 5-card hand - all three turns list all 5, and the spares are chosen as carefully as the
# cards the script actually uses.
#
# Turns 1-2 each use only 4 of their 5, so ONE card is always left in hand at End Turn, and
# that spare must never be a Strike: the Skeleton is deliberately left at exactly 9 HP
# entering turn 3 (the scripted Scout->guaranteed-3->Low Blow finale), so a spare Strike +
# the fresh Red Dice would be an obvious "socket it, roll high, kill him now" that both
# tempts the player and would preempt the finale. Turn 2's spare is therefore a second Block
# (self-target, can't touch the enemy).
#
# Turn 3 pins all 5: Scout 3 + Low Blow (the finale) + exactly ONE Strike, which is there on
# purpose as the tempting-but-losing option (it tops out at 5 damage against 9 HP), padded
# with two Blocks. The padding is what matters - left to a genuine reshuffle draw, Reinforce
# and Recombobulate turn up at the exact moment the lesson is "you cannot power through
# this", and either one hands the player a way to argue otherwise. Blocks are inert here:
# self-target, and the incoming hit is unblockable anyway. By turn 3 every starter copy has
# cycled through the discard at least once, so _force_tutorial_hand() searches BOTH piles.
const TUTORIAL_HAND_BY_TURN := {
    0: [
        "res://characters/warrior/cards/warrior_axe_attack2.tres",
        "res://characters/warrior/cards/warrior_axe_attack3.tres",
        "res://characters/warrior/cards/warrior_block1.tres",
        "res://characters/warrior/cards/warrior_block2.tres",
        "res://characters/warrior/cards/warrior_block3.tres",
    ],
    1: [
        "res://characters/warrior/cards/low_blow.tres",
        "res://characters/warrior/cards/card_recombobulate.tres",
        "res://characters/warrior/cards/reinforce.tres",
        "res://characters/warrior/cards/warrior_block4.tres",
        "res://characters/warrior/cards/warrior_block2.tres",
    ],
    2: [
        "res://characters/warrior/cards/card_scout3_no_exhaust.tres",
        "res://characters/warrior/cards/low_blow.tres",
        "res://characters/warrior/cards/warrior_axe_attack2.tres",
        "res://characters/warrior/cards/warrior_block1.tres",
        "res://characters/warrior/cards/warrior_block3.tres",
    ],
}

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

    character.discard = CardPile.new()
    character.exhaust = CardPile.new()
    relics.relics_activated.connect(_on_relics_activated)
    player.status_handler.statuses_applied.connect(_on_statuses_applied)
    start_turn()


func start_turn() -> void:
    # Muscle statuses subtract lose_strength_next_turn during this emit (one-turn-only
    # strength: fury.gd, and the Octet dice infusion). Clear it right after so the pending
    # loss is applied exactly once - it used to never reset, so any later permanent-strength
    # gain would keep getting silently drained by a stale value every subsequent turn.
    Events.check_if_losing_strength.emit()
    Global.lose_strength_next_turn = 0
    character.block = 0
    Global.player.stats.block = 0
    Global.has_rolled_6_this_turn = false
    Global.cards_played_this_turn = 0

    character.reset_mana()
    relics.activate_relics_by_type(Relic.Type.START_OF_TURN)
    Global.blue_dice_current_amount = Global.blue_dice_max_amount + Global.blue_dice_bonus_amount + Global.blue_dice_bonus_amount_fight
    Global.roll_history = []
    if Global.tutorial_on:
        _force_tutorial_hand()
    Global.dice_amount_rolled_this_turn = 0
    Global.dice_types_rolled_this_turn = {}
    Global.keep_power_on_type_change = false
    Events.player_turn_started.emit()


# Pulls this turn's scripted opening hand (TUTORIAL_HAND_BY_TURN) out of wherever each
# card currently sits - draw_pile most of the time, but by turn 3 every starter card has
# cycled through play/discard at least once, so discard has to be checked too (remove_card
# is a safe no-op on a pile that doesn't have the card, so checking both unconditionally is
# fine). Cards end up at the FRONT of draw_pile in list order, so the very next draw_cards()
# call deals them out first - anything beyond the forced list (turn 3 only forces 2 of its
# 5 cards) is a genuine reshuffle draw from whatever's left in discard.
func _force_tutorial_hand() -> void:
    var paths: Array = TUTORIAL_HAND_BY_TURN.get(Global.fight_turn, [])
    if paths.is_empty():
        return
    var forced_cards: Array[Card] = []
    for path: String in paths:
        forced_cards.append(load(path))
    for forced_card in forced_cards:
        character.draw_pile.remove_card(forced_card)
        character.discard.remove_card(forced_card)
    for i in range(forced_cards.size() - 1, -1, -1):
        character.draw_pile.cards.push_front(forced_cards[i])


func end_turn() -> void:
    Events.clear_socket.emit()
    hand.disable_hand()
    Global.fight_turn+=1
    relics.activate_relics_by_type(Relic.Type.END_OF_TURN)



func draw_card() -> void:
    reshuffle_deck_from_discard()
    hand.add_card(character.draw_pile.draw_card())
    _punch_draw_pile()
    audio_stream_player_2d.stream = preload("res://drawcardsound.wav")
    audio_stream_player_2d.play()
    reshuffle_deck_from_discard()


# The draw pile button visibly "dispenses" each drawn card. Lives here (not in hand.add_card)
# on purpose: cards granted straight to the hand by effects (add_card_to_hand_requested) never
# touched the draw pile, so punching it there would be a small visual lie.
func _punch_draw_pile() -> void:
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer:
        var draw_pile_button: Node = ui_layer.get_node_or_null("DrawPileButton")
        if draw_pile_button is CardPileOpener:
            (draw_pile_button as CardPileOpener).receive_punch(1.1)

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
    # If hand is empty, emit signal immediately
    if hand.get_child_count() == 0:
        Events.player_hand_discarded.emit()
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

    var moved_count := 0
    while not character.discard.empty():
        character.draw_pile.add_card(character.discard.draw_card())
        moved_count += 1

    character.draw_pile.shuffle()
    # Only announce a reshuffle that visibly moved something - both piles being empty (e.g.
    # the whole deck is in hand) reaches here too, and animating that would be a lie.
    if moved_count > 0:
        Events.deck_reshuffled.emit(moved_count)


func _on_card_played(card: Card) -> void:
    if card.should_exhaust():
        character.exhaust.add_card(card)
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
    
