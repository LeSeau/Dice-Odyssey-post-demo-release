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
@onready var exhaust_pile_button: CardPileOpener = %ExhaustPileButton
@onready var exhaust_pile_view: CardPileView = %ExhaustPileView

# End Turn "nothing left to do" nudge: pulses the button when the player has no dice left to
# roll, no banked power to spend, AND no Celestial card in hand (a card playable without dice) -
# i.e. every possible action this turn is exhausted. Any ONE of those still being available
# means there's still something to try, so the highlight stays off.
var _end_turn_highlight_active := false
var _end_turn_highlight_tween: Tween

# Turn-cycle guard: true from the player_turn_ended emit until the next hand finishes
# drawing (player_hand_drawn). While active, no second player_turn_ended may be emitted -
# a double emit mid-cycle re-runs the whole discard -> enemy turn -> draw chain on top of
# the in-flight one (every enemy performs its action a second time, then two 5-card hands
# get dealt). The button's disabled flag alone can't be the guard: it used to re-enable on
# a flat 3s timer, which lands mid-enemy-turn in any fight whose full cycle outlasts 3s -
# most multi-enemy fights, and nearly everything on the slower web export.
var _turn_cycle_active := false
# Generation token so a stale watchdog from cycle N can never clear/re-enable during
# cycle N+1 (the await below outlives the cycle it was armed for).
var _turn_cycle_id := 0

# Reshuffle flourish (2026-07-17): the discard->draw reshuffle used to be an invisible counter
# swap. A few mini "card backs" (plain Panels wearing the normal card frame stylebox - instantly
# reads as a face-down card at this size) now arc from the discard pile button to the draw pile
# button, each landing with a punch on the pile. Capped small: it fires mid-deal, so it has to
# stay a quick aside, not a production number.
const RESHUFFLE_MAX_MINI_CARDS := 5
const RESHUFFLE_MINI_CARD_SIZE := Vector2(30, 44)
const RESHUFFLE_MINI_CARD_STYLE := preload("res://scenes/card_ui/card_ui_normal.tres")
const RESHUFFLE_STAGGER := 0.07
const RESHUFFLE_FLIGHT_TIME := 0.5
const RESHUFFLE_ARC_HEIGHT := 110.0
# Placeholder shuffle sound: the draw tick pitched way down reads as a card riffle. Swap for a
# dedicated shuffle SFX if Julien finds one.
const RESHUFFLE_SFX := preload("res://drawcardsound.wav")

# Enemy-planted junk (2026-09-02): an enemy writing into your deck used to be a 38px art crop
# arcing to the discard - it named neither the card, nor the count, nor the pile. The whole
# presentation now lives in scenes/ui/junk_plant_presenter.gd (built in code, no .tscn): a
# real card face held readable on the stage under a caption naming the pile and the count,
# then a comet streak into that pile. BattleUI only forwards the two injection signals and
# hands it the pile buttons. Listening to the SAME signals player_handler performs the pile
# write on (never a dedicated visual one): one event, one truth - the story can never play
# without the write, and never for a card that did not land.
const JunkPlantPresenter := preload("res://scenes/ui/junk_plant_presenter.gd")
var junk_presenter

func _ready() -> void:
    Events.player_hand_drawn.connect(_on_player_hand_drawn)
    Events.deck_reshuffled.connect(_on_deck_reshuffled)
    junk_presenter = JunkPlantPresenter.new()
    junk_presenter.name = "JunkPlantPresenter"
    add_child(junk_presenter)
    junk_presenter.draw_pile_button = draw_pile_button
    junk_presenter.discard_pile_button = discard_pile_button
    Events.add_card_to_discard_requested.connect(
            _on_card_planted.bind(JunkPlantPresenter.Dest.DISCARD))
    Events.add_card_to_draw_pile_requested.connect(
            _on_card_planted.bind(JunkPlantPresenter.Dest.DRAW))
    end_turn_button.pressed.connect(_on_end_turn_button_pressed)
    draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("Draw Pile", true))
    discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("Discard Pile"))
    deck_pile_button.pressed.connect(deck_pile_view.show_current_view.bind("Deck Pile"))
    exhaust_pile_button.pressed.connect(exhaust_pile_view.show_current_view.bind("Exhaust Pile"))
    Events.force_end_turn.connect(_on_force_end_turn)
    # hover_playable_cards already fires on every roll/dice-type-change/reset (see dice.gd) -
    # covers the dice/power side. card_played covers hand composition changing (a Celestial
    # card being played away), which dice.gd's signal doesn't fire for on its own.
    Events.hover_playable_cards.connect(_update_end_turn_highlight)
    Events.card_played.connect(_on_card_played_for_highlight)
    # Motion + timing kit (instant hover-in, slow drift out, press-down, focus/hover
    # hygiene). See scenes/ui/button_feel.gd.
    ButtonFeel.attach(end_turn_button)
    # "Why would I NOT end my turn?" - hovering End Turn flashes whatever is still
    # playable in hand, so the answer arrives before the click rather than after it.
    end_turn_button.mouse_entered.connect(_on_end_turn_hovered)

func initialize_card_pile_ui() -> void:
    draw_pile_button.card_pile = char_stats.draw_pile
    draw_pile_view.card_pile = char_stats.draw_pile
    discard_pile_button.card_pile = char_stats.discard
    discard_pile_view.card_pile = char_stats.discard
    deck_pile_button.card_pile = char_stats.deck
    deck_pile_view.card_pile = char_stats.deck
    exhaust_pile_button.card_pile = char_stats.exhaust
    exhaust_pile_view.card_pile = char_stats.exhaust
    # Hidden until the first card actually exhausts (most fights never exhaust anything -
    # showing an empty pile at 0 all game would just be clutter). Never re-hides once shown;
    # nothing in the current design removes cards FROM the exhaust pile mid-fight.
    exhaust_pile_button.visible = false
    if not char_stats.exhaust.card_pile_size_changed.is_connected(_on_exhaust_pile_size_changed):
        char_stats.exhaust.card_pile_size_changed.connect(_on_exhaust_pile_size_changed)


func _on_exhaust_pile_size_changed(cards_amount: int) -> void:
    if cards_amount > 0:
        exhaust_pile_button.visible = true


func _set_char_stats(value: CharacterStats) -> void:
    char_stats = value
    mana_ui.char_stats = char_stats
    hand.char_stats = char_stats


func _on_player_hand_drawn() -> void:
    _turn_cycle_active = false
    # During the tutorial, TutorialDirector owns this button's disabled state (per-step
    # input gating) - re-enabling here would silently unlock End Turn mid-script. Same
    # guard on the watchdog re-enable below.
    if not Global.tutorial_on:
        end_turn_button.disabled = false
    _update_end_turn_highlight()


func _on_end_turn_button_pressed() -> void:
    _begin_turn_cycle()


# Emergency/Tension emit force_end_turn from the card play itself; the 1s grace lets the
# card's own flight/SFX land before the turn actually ends. The button is disabled for the
# whole grace window so a manual End Turn click can't race the delayed emit into a second
# turn cycle.
func _on_force_end_turn() -> void:
    end_turn_button.disabled = true
    _stop_end_turn_highlight()
    await get_tree().create_timer(1.0).timeout
    _begin_turn_cycle()


# The ONLY place player_turn_ended is emitted from - every way of ending the turn funnels
# through here so the cycle guard can refuse re-entry.
func _begin_turn_cycle() -> void:
    if _turn_cycle_active:
        return
    _turn_cycle_active = true
    _turn_cycle_id += 1
    var cycle_id := _turn_cycle_id
    end_turn_button.disabled = true
    _stop_end_turn_highlight()
    Events.player_turn_ended.emit()
    # Watchdog, not a schedule: player_hand_drawn is what legitimately ends the cycle and
    # re-enables the button. This only rescues a genuinely stalled cycle, so it must
    # outlast the slowest legitimate one (a 4-enemy fight on the web export) - never
    # shorten it back toward the old 3s.
    await get_tree().create_timer(20.0).timeout
    if _turn_cycle_active and cycle_id == _turn_cycle_id:
        _turn_cycle_active = false
        if not Global.tutorial_on:
            end_turn_button.disabled = false
        _update_end_turn_highlight()


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


func _on_end_turn_hovered() -> void:
    if end_turn_button.disabled:
        return
    hand.flash_playable_cards()


# The "shiny" state, upgraded (2026-08-15, STS2 audit 1.6). Our TRIGGER stays exactly as
# it was - it accounts for banked Power and Celestial cards, which makes it strictly more
# precise than the reference's "no playable cards" check. What changes is the
# PRESENTATION: a colour pulse on a static rect is easy to miss, so it now also emits an
# expanding, fading ring of light - a real "look here" shape rather than a brightness
# change on something the player has stopped looking at.
const END_TURN_RING_SIZE := 250.0
const END_TURN_RING_PERIOD := 1.5
var _end_turn_ring: TextureRect
var _end_turn_ring_tween: Tween


func _ensure_end_turn_ring() -> TextureRect:
    if is_instance_valid(_end_turn_ring):
        return _end_turn_ring
    var ring := TextureRect.new()
    ring.texture = DicePalette.glow_texture()
    ring.material = DicePalette.additive_material()
    # MUST be IGNORE: it is a child of the button and covers it entirely, so anything
    # else would swallow the click that ends the turn.
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Behind the button art, so it reads as light spilling out from under the plate
    # rather than a wash sitting on top of the label.
    ring.show_behind_parent = true
    var ring_size := Vector2(END_TURN_RING_SIZE, END_TURN_RING_SIZE)
    ring.size = ring_size
    ring.pivot_offset = ring_size / 2.0
    ring.position = end_turn_button.size / 2.0 - ring_size / 2.0
    ring.modulate = Color(1, 1, 1, 0)
    end_turn_button.add_child(ring)
    _end_turn_ring = ring
    return ring


func _start_end_turn_highlight() -> void:
    _end_turn_highlight_active = true
    # The nudge is carried ENTIRELY by the ring below, not by a modulate pulse on the
    # button. Both used to animate `modulate`, and ButtonFeel now animates it too on hover -
    # three writers on one property flicker against each other. The ring is a separate node,
    # so it can pulse forever without ever contending with hover feedback. (It is also the
    # louder signal: an expanding halo reads as "look here" far better than a brightness
    # change on something the player has already stopped looking at.)
    var ring := _ensure_end_turn_ring()
    ring.visible = true
    var gold := Color(1.0, 0.82, 0.35)
    if _end_turn_ring_tween and _end_turn_ring_tween.is_valid():
        _end_turn_ring_tween.kill()
    _end_turn_ring_tween = create_tween()
    _end_turn_ring_tween.set_loops()
    # Expand + fade out: the ring grows away from the button and dies, then restarts.
    _end_turn_ring_tween.tween_callback(func() -> void:
        ring.scale = Vector2(0.5, 0.5)
        ring.modulate = Color(gold.r, gold.g, gold.b, 0.55)
    )
    _end_turn_ring_tween.set_parallel(true)
    _end_turn_ring_tween.tween_property(ring, "scale", Vector2(0.78, 0.78), END_TURN_RING_PERIOD) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _end_turn_ring_tween.tween_property(ring, "modulate:a", 0.0, END_TURN_RING_PERIOD) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    _end_turn_ring_tween.set_parallel(false)


func _stop_end_turn_highlight() -> void:
    _end_turn_highlight_active = false
    if _end_turn_highlight_tween and _end_turn_highlight_tween.is_valid():
        _end_turn_highlight_tween.kill()
    # Deliberately NOT resetting end_turn_button.modulate here any more: the nudge no
    # longer writes it, and forcing it to white would stomp ButtonFeel's hover state if
    # the nudge switches off while the cursor is on the button.
    if _end_turn_ring_tween and _end_turn_ring_tween.is_valid():
        _end_turn_ring_tween.kill()
    if is_instance_valid(_end_turn_ring):
        _end_turn_ring.modulate = Color(1, 1, 1, 0)
        _end_turn_ring.visible = false


# tween_method target for the reshuffle arc below: quadratic bezier through an apex control
# point, positioning the mini-card by its center (it has a centered pivot + spin, so
# global_position is its top-left).
func _mini_card_arc_step(t: float, node: Control, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
    node.global_position = p0.lerp(p1, t).lerp(p1.lerp(p2, t), t) - node.size / 2.0


# An enemy just planted a card in one of the piles (the write already happened in
# player_handler on this same signal). Bound `dest` says which pile; the presenter does the rest.
func _on_card_planted(card: Card, source_global_position: Vector2, dest: int) -> void:
    if is_instance_valid(junk_presenter):
        junk_presenter.plant(card, source_global_position, dest)

func _on_deck_reshuffled(card_count: int) -> void:
    var from := discard_pile_button.global_position + discard_pile_button.size / 2.0
    var to := draw_pile_button.global_position + draw_pile_button.size / 2.0
    var n := mini(card_count, RESHUFFLE_MAX_MINI_CARDS)
    discard_pile_button.receive_punch(1.1)  # the pile visibly "gives up" its cards
    SFXPlayer.play(RESHUFFLE_SFX, false, 0.72, -2.0)
    for i in n:
        var mini_card := Panel.new()
        mini_card.add_theme_stylebox_override("panel", RESHUFFLE_MINI_CARD_STYLE)
        mini_card.size = RESHUFFLE_MINI_CARD_SIZE
        mini_card.pivot_offset = RESHUFFLE_MINI_CARD_SIZE / 2.0
        mini_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mini_card.z_index = 90
        mini_card.rotation = deg_to_rad(randf_range(-20.0, 20.0))
        mini_card.modulate.a = 0.0
        add_child(mini_card)
        mini_card.global_position = from - RESHUFFLE_MINI_CARD_SIZE / 2.0

        # Apex above BOTH piles (they sit at the same bottom-row height) so the minis sail
        # over the bottom of the screen rather than sliding straight across it. Slight per-
        # card randomization keeps the group from tracing one identical rail (the power-orb
        # "train" lesson).
        var apex := Vector2(
            lerpf(from.x, to.x, randf_range(0.35, 0.65)),
            minf(from.y, to.y) - RESHUFFLE_ARC_HEIGHT + randf_range(-25.0, 25.0)
        )
        var mini_tween := create_tween()
        mini_tween.tween_interval(RESHUFFLE_STAGGER * i)
        mini_tween.tween_property(mini_card, "modulate:a", 1.0, 0.08)
        mini_tween.parallel().tween_method(
                _mini_card_arc_step.bind(mini_card, from, apex, to),
                0.0, 1.0, RESHUFFLE_FLIGHT_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        mini_tween.parallel().tween_property(
                mini_card, "rotation",
                mini_card.rotation + deg_to_rad(randf_range(-140.0, 140.0)), RESHUFFLE_FLIGHT_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        # Fade out over the last stretch of the arc so the card reads as absorbed into the
        # pile (the punch sells the landing) rather than blinking out of existence on it.
        mini_tween.parallel().tween_property(mini_card, "modulate:a", 0.0, 0.12) \
            .set_delay(RESHUFFLE_FLIGHT_TIME - 0.12)
        mini_tween.tween_callback(draw_pile_button.receive_punch.bind(1.12))
        mini_tween.tween_callback(mini_card.queue_free)

