class_name BattleUI
extends CanvasLayer

@export var char_stats: CharacterStats : set = _set_char_stats

@onready var hand: Hand = $Hand

@onready var mana_ui: ManaUI = $ManaUI
@onready var end_turn_button: Button = %EndTurnButton
@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var deck_pile_button: CardPileOpener = %DeckPileButton
@onready var deck_pile_view: CardPileView = %DeckPileView

# End Turn "nothing left to do" nudge: pulses the button when the player has no dice left to
# roll, no banked power to spend, AND no Celestial card in hand (a card playable without dice) -
# i.e. every possible action this turn is exhausted. Any ONE of those still being available
# means there's still something to try, so the highlight stays off.
var _end_turn_highlight_active := false
var _end_turn_highlight_tween: Tween


func _ready() -> void:
    Events.player_hand_drawn.connect(_on_player_hand_drawn)
    end_turn_button.pressed.connect(_on_end_turn_button_pressed)
    draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("Draw Pile", true))
    discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("Discard Pile"))
    deck_pile_button.pressed.connect(deck_pile_view.show_current_view.bind("Deck Pile"))
    Events.force_end_turn.connect(_on_force_end_turn)
    # hover_playable_cards already fires on every roll/dice-type-change/reset (see dice.gd) -
    # covers the dice/power side. card_played covers hand composition changing (a Celestial
    # card being played away), which dice.gd's signal doesn't fire for on its own.
    Events.hover_playable_cards.connect(_update_end_turn_highlight)
    Events.card_played.connect(_on_card_played_for_highlight)

func initialize_card_pile_ui() -> void:
    draw_pile_button.card_pile = char_stats.draw_pile
    draw_pile_view.card_pile = char_stats.draw_pile
    discard_pile_button.card_pile = char_stats.discard
    discard_pile_view.card_pile = char_stats.discard
    deck_pile_button.card_pile = char_stats.deck 
    deck_pile_view.card_pile = char_stats.deck
    

func _set_char_stats(value: CharacterStats) -> void:
    char_stats = value
    mana_ui.char_stats = char_stats
    hand.char_stats = char_stats


func _on_player_hand_drawn() -> void:
    end_turn_button.disabled = false
    _update_end_turn_highlight()


func _on_end_turn_button_pressed() -> void:
    end_turn_button.disabled = true
    _stop_end_turn_highlight()
    Events.player_turn_ended.emit()
    await get_tree().create_timer(3.0).timeout
    end_turn_button.disabled = false
    _update_end_turn_highlight()


func _on_force_end_turn() -> void:
    await get_tree().create_timer(1.0).timeout
    Events.player_turn_ended.emit()


func _on_card_played_for_highlight(_card: Card) -> void:
    _update_end_turn_highlight()


# Re-evaluates whether the "nothing left to do" nudge should be on. See the comment on
# _end_turn_highlight_active above for the three conditions.
func _update_end_turn_highlight() -> void:
    if end_turn_button.disabled:
        _stop_end_turn_highlight()
        return

    var no_dice_left := (
        Global.blue_dice_current_amount <= 0 and Global.red_dice_current_amount <= 0
        and Global.evil_dice_current_amount <= 0 and Global.green_dice_current_amount <= 0
        and Global.giant_dice_current_amount <= 0 and Global.magma_dice_current_amount <= 0
        and Global.even_dice_current_amount <= 0 and Global.odd_dice_current_amount <= 0
        and Global.mech_dice_current_amount <= 0
    )
    var no_power := Global.roll_value <= 0

    var no_celestial_card := true
    for child in hand.get_children():
        if child is CardUI and child.card and child.card.can_play_without_dice:
            no_celestial_card = false
            break

    var should_highlight := no_dice_left and no_power and no_celestial_card
    if should_highlight and not _end_turn_highlight_active:
        _start_end_turn_highlight()
    elif not should_highlight and _end_turn_highlight_active:
        _stop_end_turn_highlight()


func _start_end_turn_highlight() -> void:
    _end_turn_highlight_active = true
    _end_turn_highlight_tween = create_tween()
    _end_turn_highlight_tween.set_loops()
    _end_turn_highlight_tween.tween_property(end_turn_button, "modulate", Color(1.5, 1.3, 0.7, 1.0), 1.0) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _end_turn_highlight_tween.tween_property(end_turn_button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_end_turn_highlight() -> void:
    _end_turn_highlight_active = false
    if _end_turn_highlight_tween and _end_turn_highlight_tween.is_valid():
        _end_turn_highlight_tween.kill()
    end_turn_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

