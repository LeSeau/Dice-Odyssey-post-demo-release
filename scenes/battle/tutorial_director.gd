class_name TutorialDirector
extends Node

## Data-driven replacement for the old 15-panel/flag-web tutorial (see
## tutorial_redesign_2026-07.md). Runs the 3-turn scripted fight: shows the affordance
## overlay, gates input to whatever the current step allows, and advances on the ONE
## signal each step waits for. Added as the LAST child of the Battle root in battle.tscn
## so every sibling it reaches via get_node()/find_child() already exists in the tree
## (node instancing always completes before any _ready() fires) - deliberately avoids
## reading any sibling's own @onready-cached fields, which would depend on sibling
## _ready() order instead.

const OVERLAY_SCENE := preload("res://scenes/tutorial_overlay.tscn")

const STRIKE_ID := "warrior_strike"
const BLOCK_ID := "warrior_block"
const LOW_BLOW_ID := "warrior_duo"
const REINFORCE_ID := "card_reinforce"
const RECOMBOBULATE_ID := "card_recombobulate"
const SCOUT3_ID := "card_oracle3"

const AIM_NUDGE_TIMEOUT := 4.0
# How long a step is allowed to sit with nothing the player can actually click before the
# stuck guard hands the fight back (see _on_stuck_check_timeout). Comfortably longer than the
# turn-start deal (~1.25s) and both _delay_step pauses, so a normal beat never trips it.
const STUCK_CHECK_DELAY := 2.5
const ENEMY_ARROW_DROP := 34.0
# Pause after the first Strike connects, before the "Power went back to 0" box appears.
const POST_HIT_BEAT := 1.0
# Same idea for the socketed Block: let the die land, the card resolve and the Block badge pop
# on the health bar before the box that names the number shows up.
const POST_BLOCK_BEAT := 0.9
# Only used if the Skeleton's intent can't be read at all (see _enemy_intent_damage) - keep in
# sync with big_hit_damage on crab_tutorial_ai.tscn's TutorialAttack.
const BIG_HIT_FALLBACK := 35
# Padding around a die icon's 32x32 rect for its pulse frame - a little roomier than the
# default so the badge doesn't look shrink-wrapped onto the icon.
const DICE_SLOT_PULSE_PAD := 5.0

var battle: Node2D
var overlay: TutorialOverlay
var active_dice: Dice
var roll_button: Button
var dice_interface: DiceInterface
var battle_ui_node: Node
var hand: Hand
var end_turn_button: Button
var enemy_handler: Node
var scout_panel: Panel
var scout_exit_button: Button

var _steps: Array[Callable] = []
var _step_index := -1
var _enemy_highlight_on := false
var _scout_gated := false
var _aim_nudge_timer: Timer
var _stuck_timer: Timer
var _lifted_card: CardUI
var _power_alpha_boosted := false

# The one completion signal the current step is waiting on (see _wait()). Tracked so
# _reset_between_steps()/skip can cleanly disconnect a wait that never fired.
var _pending_signal: Signal
var _pending_callable: Callable
var _has_pending := false

# Last gate applied - re-applied on player_hand_drawn, because cards drawn AFTER a gate
# was applied come in with disabled=false (Hand.add_card instantiates fresh CardUIs), and
# the turn-start draw finishes ~1.3s after the step that locked the hand.
var _current_gate: Dictionary = {}


func _ready() -> void:
    if not Global.tutorial_on:
        return

    battle = get_parent()
    active_dice = battle.get_node("ActiveDice") as Dice
    roll_button = active_dice.get_node("Button") as Button
    dice_interface = battle.get_node("DiceInterface") as DiceInterface
    battle_ui_node = battle.get_node("BattleUI")
    hand = battle_ui_node.find_child("Hand", true, false) as Hand
    end_turn_button = battle_ui_node.find_child("EndTurnButton", true, false) as Button
    enemy_handler = battle.get_node("EnemyHandler")
    scout_panel = battle.get_node("ScoutPanel") as Panel
    scout_exit_button = scout_panel.get_node("ExitButton") as Button

    overlay = OVERLAY_SCENE.instantiate()
    overlay.setup()
    # Deferred rather than a direct add_child(): battle is itself still mid-entering the
    # tree at this point (TutorialDirector's _ready() runs as part of THAT same cascade) -
    # a CanvasLayer added to a not-yet-fully-entered parent can end up structurally parented
    # (get_node() etc. all work) without ever registering with the viewport's rendering pass,
    # so it never actually draws even once battle finishes entering. call_deferred runs this
    # at the next true idle point, once the whole cascade has settled, so overlay enters the
    # tree normally. Every property set below (start(), and later set_dim()/set_text() from
    # the first step) still applies immediately regardless - those are plain property writes
    # on already-setup() nodes, not tree-dependent - so the overlay simply appears already
    # fully dressed with the current step's content the moment it's actually able to render.
    battle.call_deferred("add_child", overlay)
    overlay.start()
    overlay.skip_pressed.connect(_on_skip_pressed)

    _aim_nudge_timer = Timer.new()
    _aim_nudge_timer.one_shot = true
    _aim_nudge_timer.wait_time = AIM_NUDGE_TIMEOUT
    add_child(_aim_nudge_timer)
    _aim_nudge_timer.timeout.connect(_on_aim_nudge_timeout)

    _stuck_timer = Timer.new()
    _stuck_timer.one_shot = true
    add_child(_stuck_timer)
    _stuck_timer.timeout.connect(_on_stuck_check_timeout)

    Events.card_aim_started.connect(_on_card_aim_started)
    Events.card_aim_ended.connect(_on_card_aim_ended)
    Events.player_hand_drawn.connect(_on_player_hand_drawn)

    _build_steps()
    Events.battle_over_screen_requested.connect(_on_battle_over_screen_requested)
    Events.battle_started.connect(_advance, CONNECT_ONE_SHOT)


# Registers THE completion signal for the current step. arg_count is how many arguments
# the signal emits - _advance() takes none, and in Godot 4 connecting a 0-arg callable to
# an N-arg signal is accepted at connect time but ERRORS AT EMIT TIME and the handler
# silently never runs (this exact bug shipped in the first pass: dice_rolled emits
# (type, value), so "roll to continue" steps never advanced). unbind(N) discards the
# emitted arguments so the arity always matches.
func _wait(sig: Signal, arg_count: int = 0) -> void:
    _clear_pending()
    _pending_callable = _advance if arg_count == 0 else _advance.unbind(arg_count)
    _pending_signal = sig
    _has_pending = true
    sig.connect(_pending_callable, CONNECT_ONE_SHOT)


func _clear_pending() -> void:
    if _has_pending and _pending_signal.is_connected(_pending_callable):
        _pending_signal.disconnect(_pending_callable)
    _has_pending = false


# Like _wait(), but only advances when the emitted value passes `accepts` - anything else is
# ignored and the step simply stays put, still asking for the thing it asked for.
#
# Every "play this card" step used to be a plain _wait(Events.card_played). There is exactly
# ONE emitter of that signal (Card.play) and it does not care which card it was, so ANY card
# reaching play advanced the step. One off-script play therefore shifted every remaining step
# by one, and a few beats later the script asked for a card that was already in the discard -
# which _apply_gate answers by disabling the whole hand, ROLL, every dice slot AND End Turn at
# once. That is the hard lock an itch playtester hit: the tutorial was asking for Reinforce
# while Reinforce was in the discard, and "Skip Tutorial" was the only thing left clickable.
#
# The gate holes that let the off-script play happen in the first place are closed in hand.gd,
# but the director should never be one mis-timed click away from soft-locking regardless of how
# a card got played, so the waits name their card now.
func _wait_for(sig: Signal, accepts: Callable) -> void:
    _clear_pending()
    # Deliberately NOT CONNECT_ONE_SHOT: the connection has to survive emissions that don't
    # match. _clear_pending() tears it down instead, and _advance() always runs that first.
    _pending_callable = func(value: Variant) -> void:
        if accepts.call(value):
            _advance()
    _pending_signal = sig
    _has_pending = true
    sig.connect(_pending_callable)


# Both read the card ids straight out of the gate the step just applied, rather than taking
# their own list: the step's "these cards are clickable" and its "this is what I'm waiting for"
# can then never drift apart, which is precisely the kind of edit-one-forget-the-other slip
# that ends in a locked tutorial. Call them immediately after _apply_gate.

# card_played emits the Card resource itself...
func _wait_card_played() -> void:
    var allowed_ids: Array = _current_gate.get("cards", [])
    var accepts := func(value: Variant) -> bool:
        return value is Card and allowed_ids.has((value as Card).id)
    _wait_for(Events.card_played, accepts)


# ...while card_charged emits the CardUI holding it.
func _wait_card_charged() -> void:
    var allowed_ids: Array = _current_gate.get("cards", [])
    var accepts := func(value: Variant) -> bool:
        if not (value is CardUI):
            return false
        var c: Card = (value as CardUI).card
        return c != null and allowed_ids.has(c.id)
    _wait_for(Events.card_charged, accepts)


# Lets a step breathe before it draws anything (see _step_t1_5). Returns FALSE if the tutorial
# moved on while we waited - skipped, or advanced by something else - in which case the caller
# must return immediately without touching the overlay, since _reset_between_steps has already
# run on behalf of whatever is on screen now. Without this guard a skip during the pause would
# resurrect a dead step's box over a normal fight.
func _delay_step(seconds: float) -> bool:
    var resumed_at := _step_index
    await get_tree().create_timer(seconds).timeout
    return Global.tutorial_on and _step_index == resumed_at and is_instance_valid(overlay)


func _build_steps() -> void:
    _steps = [
        # _step_t1_relic is deliberately OUT of the sequence (Julien: "breaks the rhythm too
        # much") - a relic aside between the last roll and the first card stalls the build-up.
        # The function is kept intact so it can be dropped back in wherever it fits later.
        _step_t1_1, _step_t1_2, _step_t1_3_power, _step_t1_3, _step_t1_3b,
        _step_t1_4, _step_t1_4b, _step_t1_5,
        _step_t1_6, _step_t1_7, _step_t1_7b, _step_t1_8, _step_t1_9,
        _step_t1_10_block, _step_t1_10,
        _step_t2_switch_blue,
        _step_t2_1, _step_t2_2, _step_t2_3, _step_t2_4, _step_t2_5,
        _step_t2_6, _step_t2_7, _step_t2_8, _step_t2_9,
        _step_t3_1, _step_t3_1b, _step_t3_2, _step_t3_3, _step_t3_4, _step_t3_5, _step_t3_6,
    ]


func _advance() -> void:
    _reset_between_steps()
    _step_index += 1
    if _step_index >= _steps.size():
        return
    _steps[_step_index].call()


# Baseline teardown before every step - clears every affordance and locks all input, so
# each step's on-enter only has to turn ON what IT needs rather than also guess what the
# previous step might have left on.
func _reset_between_steps() -> void:
    if not is_instance_valid(overlay):
        return
    _clear_pending()
    overlay.clear_all()
    _apply_gate({})
    if _enemy_highlight_on:
        var e := _enemy()
        if e:
            e.set_target_highlight(false)
        _enemy_highlight_on = false
    _unlift_card()
    _boost_power_visibility(false)
    _ungate_scout_faces()
    _aim_nudge_timer.stop()


# ---------------------------------------------------------------- Gating

# gate keys: "roll" (bool), "cards" (Array[String] of allowed card ids), "dice_types"
# (Array[String] of allowed dice-interface slot types), "end_turn" (bool).
func _apply_gate(gate: Dictionary) -> void:
    _current_gate = gate
    roll_button.disabled = not gate.get("roll", false)

    var allowed_ids: Array = gate.get("cards", [])
    # Mirrored onto the Hand so cards that arrive LATER land gated too - the loop below only
    # reaches the ones that exist right now, and Hand hands out fresh CardUIs (turn-start deal)
    # and re-enables returning ones (cancelled drag) on its own schedule. See
    # Hand.tutorial_card_gate for the two leaks this closes.
    hand.tutorial_card_gate = allowed_ids
    for card_ui: CardUI in hand.get_children():
        card_ui.disabled = not (card_ui.card and allowed_ids.has(card_ui.card.id))

    var allowed_dice: Array = gate.get("dice_types", [])
    for dtype: String in DiceInterface.DICE_TYPE_TO_NODE:
        var slot: Control = dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE[dtype])
        if slot:
            slot.mouse_filter = Control.MOUSE_FILTER_STOP if allowed_dice.has(dtype) else Control.MOUSE_FILTER_IGNORE

    end_turn_button.disabled = not gate.get("end_turn", false)
    _arm_stuck_check()


func _gate_scout_faces(allowed_index: int) -> void:
    _scout_gated = true
    scout_exit_button.disabled = true
    # Locking the faces here only covers the window between scout_effect firing and the panel
    # finishing its staggered reveal: battle.gd makes each face clickable from a tween callback
    # that lands AFTER this runs, which would hand the locked ones straight back. Hence also
    # telling battle.gd which index survives (see its tutorial_scout_allowed_index).
    battle.tutorial_scout_allowed_index = allowed_index
    for i in range(battle.scout_faces.size()):
        var face: Control = battle.scout_faces[i]
        if i != allowed_index:
            face.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ungate_scout_faces() -> void:
    if not _scout_gated:
        return
    _scout_gated = false
    scout_exit_button.disabled = false
    battle.tutorial_scout_allowed_index = -1
    # Never touches modulate: this runs while the panel may still be playing its close
    # animation (the unpicked faces are mid fade-out), and stomping them back to white would
    # flash them solid again. The halo is a separate child node, so dropping it here is safe -
    # by this point the picked face has already gone transparent behind its flying clone.
    battle.clear_scout_highlight()
    for face: Control in battle.scout_faces:
        face.mouse_filter = Control.MOUSE_FILTER_STOP


# Cards drawn after a gate was applied arrive interactive (fresh CardUI instances) - the
# turn-start hand finishes dealing ~1.3s after the step that locked it, so re-lock. Also
# runs after battle_ui's own handler (it connected first, being an earlier child), which
# unconditionally re-enables End Turn - re-applying here makes the gate win.
func _on_player_hand_drawn() -> void:
    if not Global.tutorial_on:
        return
    _apply_gate(_current_gate)


# ---------------------------------------------------------------- Stuck guard
#
# Last-resort net. Every gate is a whitelist - "only these things are clickable" - so a step
# whose required thing isn't there leaves NOTHING clickable except Skip. That is not a
# hypothetical: it shipped to itch, where a player who "just started clicking things" reached
# the Reinforce step with Reinforce already in the discard and had exactly one live button on
# the whole screen.
#
# The specific desync behind that report is fixed above (specific waits) and in hand.gd (no
# more cards slipping out from under the gate), but a scripted 3-turn fight has a lot of
# surface area and players will keep finding new ways through it. So rather than trusting the
# script to be airtight, this checks the only thing that actually matters - can the player
# still DO the thing the current step is asking for - and hands the fight back if not.
# Releasing the tutorial early is always recoverable; a dead screen never is.

func _arm_stuck_check() -> void:
    if not Global.tutorial_on or _stuck_timer == null:
        return
    _stuck_timer.start(STUCK_CHECK_DELAY)


func _on_stuck_check_timeout() -> void:
    if not Global.tutorial_on or not is_instance_valid(overlay):
        return
    # A card being dragged or aimed has been reparented to the ui_layer, so it isn't a hand
    # child and a card step reads as unsatisfiable for as long as the player holds it. Look
    # again later rather than judging mid-gesture.
    if Global.dragging_card or _gate_is_actionable():
        _arm_stuck_check()
        return
    _release_tutorial(
        "[center]Alright, you're improvising! The tutorial will step aside, this fight is yours to finish. [color=gold]Roll[/color] your Dice, play [color=#c896ff]Cards[/color] with the [color=red]Power[/color] you build, and [color=gold]end your turn[/color] when you're done.")


# Is there anything on screen right now that the player can click to move this step forward?
func _gate_is_actionable() -> bool:
    if _current_gate.get("end_turn", false):
        return true
    if _current_gate.get("roll", false) and _can_roll_now():
        return true
    for dtype: String in _current_gate.get("dice_types", []):
        if dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE.get(dtype, "")) != null:
            return true
    var allowed_ids: Array = _current_gate.get("cards", [])
    for card_ui: CardUI in hand.get_children():
        # visible matters: a card socketed on the Red Dice is hidden but is still a hand
        # child, and it cannot be played from the hand while it sits in the socket.
        if card_ui.visible and card_ui.card and allowed_ids.has(card_ui.card.id):
            return true
    # Nothing gated in at all means the step is waiting on the overlay's own Continue button,
    # or on the Scout panel (which gates its own faces via battle.gd). Fine either way - as
    # long as one of them is actually on screen.
    if _current_gate.is_empty():
        return _overlay_awaits_click() or scout_panel.visible
    return false


func _overlay_awaits_click() -> bool:
    if not is_instance_valid(overlay):
        return false
    # is_visible_in_tree(), not .visible: both buttons live inside panels that get hidden as a
    # whole, so their own flag can read true while nothing is drawn.
    if overlay.continue_button and overlay.continue_button.is_visible_in_tree():
        return true
    return overlay.welcome_button and overlay.welcome_button.is_visible_in_tree()


# Mirrors dice.gd::roll_dice's own preconditions - a ROLL step is only actionable if pressing
# the button would actually roll something rather than just play the error sound.
func _can_roll_now() -> bool:
    var amount_prop: String = DiceInterface.DICE_TYPE_TO_AMOUNT.get(Global.dice_type, "")
    if amount_prop.is_empty() or int(Global.get(amount_prop)) <= 0:
        return false
    if Global.dice_type == "red":
        return active_dice.charged_card_texture != null \
            and active_dice.charged_card_texture.texture != null
    return true


# ---------------------------------------------------------------- Lookups

func _find_card_ui(card_id: String) -> CardUI:
    for card_ui: CardUI in hand.get_children():
        if card_ui.card and card_ui.card.id == card_id:
            return card_ui
    return null


# Lifts+de-rotates+scales the actual CardUI node (same tween Hand already runs on real mouse
# hover) instead of drawing an external rectangle over it - see highlight_card_lift's comment
# in hand.gd for why an external rect doesn't work here (fanned cards are rotated, a Rect2
# highlight never is). Only one card is ever lifted by the tutorial at a time, so a single
# tracked reference is enough.
func _lift_card(card_id: String) -> void:
    _unlift_card()
    var c := _find_card_ui(card_id)
    if c:
        _lifted_card = c
        hand.highlight_card_lift(c)


func _unlift_card() -> void:
    if _lifted_card and is_instance_valid(_lifted_card):
        hand.clear_card_lift(_lifted_card)
    _lifted_card = null


# Blinking gold frame around the lifted card, same affordance the dice slots get. Deferred by
# the lift's own tween time because the frame is a static Rect2 - drawn immediately it would
# sit where the card USED to be and stay there while the card rose out of it. Safe to read a
# plain rect once settled: highlight_card_lift zeroes the card's rotation, so the lifted card
# is the one card in the fan that is actually axis-aligned.
#
# annotate_requirement additionally captions the card's requirement ribbon (see
# _card_requirement_rect). It rides along here rather than in its own deferred function
# because it needs the exact same settle-wait and the exact same staleness guards - two
# independent timers racing the same lift would just be two ways to get it wrong.
func _pulse_lifted_card(annotate_requirement: bool = false) -> void:
    var target := _lifted_card
    var started_at := _step_index
    await get_tree().create_timer(hand.hover_time + 0.05).timeout
    if _step_index != started_at or not Global.tutorial_on:
        return
    if not is_instance_valid(target) or target != _lifted_card or not is_instance_valid(overlay):
        return
    # Transform-mapped rather than get_global_rect(): the lifted card is SCALED, and
    # get_global_rect() reports the unscaled size, which would undersize the frame.
    overlay.show_pulse(target.get_global_transform() * Rect2(Vector2.ZERO, target.size), 4.0)
    if not annotate_requirement:
        return
    var ribbon := _card_requirement_rect(target)
    if ribbon.size == Vector2.ZERO:
        return
    # Note on the LEFT with a right-pointing arrow: the rest of the fan sits immediately right
    # of the lifted card, and an arrow coming down onto the ribbon from above would have to
    # cross the card's own artwork. Left of the card at ribbon height is open floor.
    # "Power" picks up the glyph automatically (show_info_note runs the authored-text pass).
    overlay.show_info_note_pointing(
        "Power requirement to play this Card", ribbon, TutorialOverlay.PointerDir.RIGHT)


# Screen rect of the lifted card's requirement ribbon (the "MAX 3" bar). Mapped through the
# card's global transform for the same reason _pulse_lifted_card does it - the lifted card is
# scaled, so get_global_rect() on a child would report the unscaled size and land short.
func _card_requirement_rect(card_ui: CardUI) -> Rect2:
    if not is_instance_valid(card_ui):
        return Rect2()
    var ribbon := card_ui.requirement_panel
    if ribbon == null or not ribbon.visible:
        return Rect2()
    # The ribbon's OWN global transform already folds in every ancestor's scale, so mapping
    # its unscaled local rect through it gives the true drawn rect in one step. Reading
    # get_global_position() and pairing it with the raw size would land the right corner but
    # the wrong width (size is authored, unscaled).
    return ribbon.get_global_transform() * Rect2(Vector2.ZERO, ribbon.size)


# dice.gd renders a Power of 0 at 40% alpha (see its _on_* handlers). Steps whose subject is
# that very 0 turn it solid, then hand it back to dice.gd's own rule on teardown.
func _boost_power_visibility(on: bool) -> void:
    var power_label := active_dice.get_node_or_null("CurrentPower") as Control
    if not power_label:
        return
    if on:
        _power_alpha_boosted = true
        power_label.modulate.a = 1.0
    elif _power_alpha_boosted:
        _power_alpha_boosted = false
        power_label.modulate.a = 0.4 if Global.roll_value == 0 else 1.0


func _enemy() -> Enemy:
    for child in enemy_handler.get_children():
        if child is Enemy:
            return child
    return null


func _roll_button_rect() -> Rect2:
    return roll_button.get_global_rect()


# The die FACE, not the ActiveDice control (which also spans the ROLL button below it) - a
# sideways arrow has to line up with the middle of the die itself.
func _active_die_rect() -> Rect2:
    var die := active_dice.get_node_or_null("Panel/DiceDisplay") as Control
    return die.get_global_rect() if die else _roll_button_rect()


func _dice_slot_rect(dtype: String) -> Rect2:
    var slot: Control = dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE[dtype])
    return slot.get_global_rect() if slot else Rect2()


# The die ICON inside a slot, not the whole slot. A slot is a VBoxContainer holding a 32x32
# die texture with a small "N/N" count label underneath, so its rect's centre sits well below
# the die: framing/pointing at the slot rect put the highlight ~7px above the die but ~40px
# below it, which reads as misaligned (Julien: "the red dice highlight is slightly off
# centered"). Gating/clicking still uses the whole slot - this is purely what to draw around.
func _dice_slot_icon_rect(dtype: String) -> Rect2:
    var slot: Control = dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE[dtype])
    if not slot:
        return Rect2()
    for child in slot.get_children():
        if child is TextureRect:
            return (child as TextureRect).get_global_rect()
    return slot.get_global_rect()


func _socket_rect() -> Rect2:
    var socket := active_dice.get_node("CardDropArea") as Control
    return socket.get_global_rect()


func _power_number_rect() -> Rect2:
    var power := active_dice.get_node("CurrentPower") as Control
    var r := power.get_global_rect()
    # CurrentPower is a fixed ~90x96 Label with the digit LEFT-aligned horizontally and
    # CENTER-aligned vertically inside it (dice.tscn) - so the visible glyph sits at the left-
    # middle, far from the full rect's center/top. Return a tight box on the glyph so the glow
    # centers on it and the arrow (via _point_above) sits just above the digit, not high above
    # the label's empty top margin.
    var glyph_center := Vector2(r.position.x + r.size.x * 0.28, r.get_center().y)
    return Rect2(glyph_center - Vector2(30, 30), Vector2(60, 60))


func _world_to_screen(world_pos: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform() * world_pos


# Where a DOWN pointer should aim so its tip hovers just above the target: the midpoint of
# the target's TOP edge (the overlay places the arrow tip at the given point minus a small
# gap). Aiming at rect centers put the arrow tip visually INSIDE tall targets like the die.
func _point_above(rect: Rect2) -> Vector2:
    return Vector2(rect.get_center().x, rect.position.y)


# Midpoint of the target's BOTTOM edge - for an UP pointer that sits below the target (used
# when the target hugs the top of the screen and a DOWN arrow above it would clip off-screen).
func _point_below(rect: Rect2) -> Vector2:
    return Vector2(rect.get_center().x, rect.position.y + rect.size.y)


# Midpoints of the LEFT / RIGHT edges, for the sideways pointers (RIGHT sits left of its
# target and vice versa - see show_pointer).
func _point_left_of(rect: Rect2) -> Vector2:
    return Vector2(rect.position.x, rect.get_center().y)


func _point_right_of(rect: Rect2) -> Vector2:
    return Vector2(rect.position.x + rect.size.x, rect.get_center().y)


# IntentUI's local Y offset is already calibrated per-enemy (enemy.gd::update_enemy(), scaled
# by sprite height/sprite_y_offset) to sit just above that enemy's head - reusing its rect is
# far more reliable than guessing a fixed offset from the enemy's origin, which is what
# _enemy_arrow_point() used to do (a hardcoded Vector2(0, -90) that only happened to roughly
# fit the tutorial's own Skeleton).
func _enemy_intent_rect() -> Rect2:
    var e := _enemy()
    if not e or not e.has_node("IntentUI"):
        return Rect2()
    var intent := e.get_node("IntentUI") as Control
    return Rect2(_world_to_screen(intent.global_position), intent.size)


# The single relic ICON, not the whole RelicBar - the bar spans ~450px, and glowing that
# whole width washed most of the screen gold (Julien: "insanely intense & big"). The Dice Bag
# is the only relic during the tutorial, so the first RelicUI child of the handler's row is
# it. All in run.tscn's TopBar, outside battle.tscn - reached by name since TutorialDirector
# otherwise only touches nodes inside its own Battle root.
func _relic_icon_rect() -> Rect2:
    var handler := get_tree().root.find_child("RelicHandler", true, false) as RelicHandler
    if not handler or not handler.relics or handler.relics.get_child_count() == 0:
        return Rect2()
    var first := handler.relics.get_child(0)
    return (first as Control).get_global_rect() if first is Control else Rect2()


# Aim point for the DOWN arrow over the enemy - just below the top of the intent icon rather
# than above it, so the arrow sits closer to the Skeleton (Julien: "still a bit far, move it
# slightly down"). ENEMY_ARROW_DROP pushes the aim point down into the icon.
func _enemy_arrow_point() -> Vector2:
    var rect := _enemy_intent_rect()
    if rect.size != Vector2.ZERO:
        return _point_above(rect) + Vector2(0, ENEMY_ARROW_DROP)
    var e := _enemy()
    return _world_to_screen(e.global_position) + Vector2(0, -60) if e else Vector2.ZERO


# The Block badge (shield + number) on the player's health bar. StatsUI is a Control under
# Player, a Node2D, so like the enemy intent its rect is in canvas space and has to go through
# _world_to_screen. Returns an empty rect while block is 0, since the badge's contents are
# hidden then (stats_ui.gd::update_stats) and there'd be nothing to point at.
func _player_block_rect() -> Rect2:
    var p := _player()
    if not p or _player_block() <= 0:
        return Rect2()
    # The badge now hangs off the left edge of the health bar itself (it used to be a
    # sibling of Health pulled over the bar by a negative HBox separation), so it lives
    # one level deeper than it did.
    var badge := p.get_node_or_null("StatsUI/Health/HealthBar/Block") as Control
    if not badge:
        return Rect2()
    return Rect2(_world_to_screen(badge.global_position), badge.size)


func _player() -> Player:
    return Global.player as Player


func _player_block() -> int:
    var p := _player()
    if not p or not p.stats:
        return 0
    return p.stats.block


func _enemy_health() -> int:
    var e := _enemy()
    if not e or not e.stats:
        return 0
    var hp: int = e.stats.health
    return hp


# The number currently painted on the enemy's intent icon. The tutorial Skeleton's intent
# base_text is just "%s", so current_text IS the damage it will deal - reading it beats
# hardcoding, since it already accounts for whatever modifiers are in play and can't drift if
# that swing is ever retuned.
func _enemy_intent_damage() -> String:
    var e := _enemy()
    if e and e.current_action and e.current_action.intent:
        var painted: String = str(e.current_action.intent.current_text)
        if painted.is_valid_int():
            return painted
    return str(BIG_HIT_FALLBACK)


func _highlight_enemy() -> void:
    var e := _enemy()
    if e:
        e.set_target_highlight(true)
        _enemy_highlight_on = true


# ---------------------------------------------------------------- Aim nudge

func _on_card_aim_started(_card_ui: CardUI) -> void:
    _aim_nudge_timer.start()


func _on_card_aim_ended(_card_ui: CardUI) -> void:
    _aim_nudge_timer.stop()


func _on_aim_nudge_timeout() -> void:
    if not is_instance_valid(overlay):
        return
    overlay.nudge_pointer()
    var e := _enemy()
    if e:
        e.set_target_highlight(true)


# ---------------------------------------------------------------- Skip

func _on_skip_pressed() -> void:
    _release_tutorial()


# The one way the tutorial ends early, shared by the Skip button and the stuck guard: every
# input un-gated, forced rolls and scout faces dropped, director inert for the rest of what is
# now a normal fight. Kept in a single place so there is only one teardown to get right.
#
# closing_note is for the stuck guard - the player didn't ask for the tutorial to end, so it
# says so and reminds them what the controls are, then closes on Continue. Skip passes nothing
# and the overlay just goes away, since pressing Skip already said everything.
func _release_tutorial(closing_note: String = "") -> void:
    Global.tutorial_forced_rolls = []
    Global.tutorial_forced_scout_faces = []
    _reset_between_steps()  # also clears the pending completion-signal wait, un-gates the
                            # scout faces and drops the finale's halo
    if _stuck_timer:
        _stuck_timer.stop()
    # Must be set false BEFORE any further hand draws: _on_player_hand_drawn and the
    # battle_over hook both early-return on this, turning the director inert for the
    # rest of the (now normal) fight. Also before _apply_gate below, whose _arm_stuck_check
    # would otherwise put the guard straight back on duty.
    Global.tutorial_on = false
    _apply_gate({"roll": true, "cards": _all_card_ids(), "dice_types": DiceInterface.DICE_TYPE_TO_NODE.keys(), "end_turn": true})
    # AFTER that _apply_gate, which mirrors its own (hand-shaped, already-stale) allow-list onto
    # the Hand: from here on every card drawn or returned must come back fully interactive.
    hand.tutorial_card_gate = null
    # An enemy action whose damage depends on tutorial_on has just changed what it will do -
    # today that is the Skeleton, whose 35-damage finale is off the table from here. Its intent
    # was computed while the script was still running, so without this redraw the number on
    # screen would keep advertising a hit that can no longer land. Same intent-vs-reality
    # divergence tutorial_skeleton_action.gd warns about in its header, just in the player
    # favour. update_intent() re-reads the CURRENT action rather than picking a new one, so the
    # enemy still does what it was telegraphing - only the number is refreshed.
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            enemy.update_intent()
    if closing_note.is_empty():
        overlay.shutdown()
        return
    overlay.set_dim(TutorialOverlay.Dim.NONE)
    overlay.skip_button.hide()
    overlay.set_text(closing_note, "near_dice", true)
    overlay.continue_pressed.connect(_on_release_note_dismissed, CONNECT_ONE_SHOT)


func _on_release_note_dismissed() -> void:
    if is_instance_valid(overlay):
        overlay.shutdown()


func _all_card_ids() -> Array:
    var ids: Array = []
    for card_ui: CardUI in hand.get_children():
        if card_ui.card and not ids.has(card_ui.card.id):
            ids.append(card_ui.card.id)
    return ids


# ---------------------------------------------------------------- Victory hook
# battle_over_panel.gd skips its own auto-advance-to-rewards while tutorial_on is true
# (see the change there) specifically so this can own the win moment instead - a
# battle_over_screen_requested during turn 3's kill both ends T3.6 and opens T3.7.
func _on_battle_over_screen_requested(_text: String, type: int) -> void:
    if type != BattleOverPanel.Type.WIN:
        return
    if not Global.tutorial_on:
        return
    _advance()


# ================================================================== STEPS

# ---- TURN 1: "Learn the machine" --------------------------------------------------

# Gets the dedicated title-card presentation (show_welcome) instead of the generic step box -
# it's the first thing a new player ever sees, so it opens the game rather than warning them
# about something. Warm dim to match, so the card isn't a lit box on a switched-off screen.
func _step_t1_1() -> void:
    overlay.set_dim(TutorialOverlay.Dim.FULL, TutorialOverlay.DIM_TINT_WARM)
    overlay.show_welcome(
        "Welcome to Dice Odyssey!",
        "[center]Down here, luck is not something you hope for. It's something you [color=#f2c14e]make happen[/color].\nCombat runs on two things: [color=#f2c14e]Dice[/color] and [color=#c896ff]Cards[/color].")
    _apply_gate({})
    _wait(overlay.continue_pressed)


# Every roll prompt aims a SIDEWAYS arrow at the ROLL button from the corridor between the
# hero and the dice panel. Two reasons it isn't the old DOWN arrow above ROLL: that one landed
# squarely on top of the die face, and coming in from the left keeps the whole opening beat in
# one part of the screen. It aims at ROLL rather than the die because ROLL is what to click.
func _step_t1_2() -> void:
    Global.tutorial_forced_rolls = [4, 3, 6, 6]
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Let's start by rolling a [color=#4a90d9]Blue Dice[/color]!", "near_dice", false)
    overlay.show_pointer(_point_left_of(_roll_button_rect()), TutorialOverlay.PointerDir.RIGHT)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


# The Power payoff gets its OWN Continue-gated beat before the "keep stacking" prompt. Showing
# both at once (a note pinned by the Power AND a hero box telling you to roll again) split the
# player's attention across two boxes at the exact moment the core resource is introduced.
# Numbers are read live rather than hardcoded to the forced 4, so the sentence can't drift out
# of sync with what actually landed.
func _step_t1_3_power() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.show_glow(_power_number_rect())
    overlay.show_pointer(_point_right_of(_power_number_rect()), TutorialOverlay.PointerDir.LEFT)
    overlay.set_text(
        "[center]See that [color=gold]%d[/color]? That's your [color=red]Power[/color], built from your rolls, and what you spend to play [color=#c896ff]Cards[/color]." % Global.roll_value,
        "right_of_power", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_3() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]You could spend it now, or roll a [color=gold]same-color Dice[/color] and stack even more [color=red]Power[/color]. Try it!",
        "near_dice", false)
    overlay.show_pointer(_point_left_of(_roll_button_rect()), TutorialOverlay.PointerDir.RIGHT)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


# Third roll is forced to a 6 - a max roll, which already triggers dice.gd's own gold-flash/
# particle/hit-stop celebration for free, so the buildup caps on the game's best-roll juice
# right before the payoff instead of feeling like a third repeat of the same click.
func _step_t1_3b() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Yes! Roll your last [color=#4a90d9]Blue Dice[/color], aim for the moon!", "near_dice", false)
    overlay.show_pointer(_point_left_of(_roll_button_rect()), TutorialOverlay.PointerDir.RIGHT)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


# Moved to AFTER all 3 Blue rolls rather than before the first one (where a pure Dice-Bag
# reading beat used to sit, timed to the Blue slot's pre-roll 3/2 number) - opening on a relic
# explanation before the player has even clicked ROLL once read as a stray "wait, what?"
# aside. Explaining it in hindsight ("that's why you got 3 rolls") needs no reference to the
# current dice count at all (which is back to a boring 0/2 by now anyway), so it points at the
# relic bar icon instead.
func _step_t1_relic() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    var relic_rect := _relic_icon_rect()
    overlay.show_glow(relic_rect)
    if relic_rect.size != Vector2.ZERO:
        # UP arrow sitting BELOW the relic (it's at the very top of the screen, so a DOWN arrow
        # above it would clip off the top edge).
        overlay.show_pointer(_point_below(relic_rect), TutorialOverlay.PointerDir.UP)
    overlay.set_text(
        "[center]You had [color=gold]3 Blue Dice[/color] to roll: [color=gold]2[/color] from your inventory, and [color=gold]1[/color] from your [color=gold]Relic[/color], glowing top-left. Relics quietly make you stronger. [color=gold]Hover it[/color] to read its tooltip!",
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


# The payoff line lands on its own before any instruction - the player gets a beat to enjoy
# the 13 they just built, then presses Continue into the "how to spend it" step.
func _step_t1_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]%d [color=red]Power[/color]! Now let's use it!" % Global.roll_value,
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_4b() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center][color=#c896ff]Strike[/color] deals damage equal to your [color=red]Power[/color]. The card updates to show exactly how much.\nDrag it onto the Skeleton and release to smack him!",
        "near_dice", false)
    _lift_card(STRIKE_ID)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [STRIKE_ID]})
    _wait_card_played()
    _pulse_lifted_card()


# End-turn steps use this instead of a bare _wait(player_turn_started): the box would otherwise
# stay up through the WHOLE enemy turn, covering the attack the player is meant to watch land
# (Julien: "you don't see the enemy attacking you because of it"). Clearing on turn_ended hands
# the screen back the instant they commit, while the step itself still advances on turn_started.
func _wait_end_turn() -> void:
    Events.player_turn_ended.connect(_on_tutorial_turn_ended, CONNECT_ONE_SHOT)
    _wait(Events.player_turn_started)


func _on_tutorial_turn_ended() -> void:
    if Global.tutorial_on and is_instance_valid(overlay):
        overlay.clear_all()


# Holds off for a beat so the hit, the damage number and the Power dropping to 0 all land
# BEFORE a box appears to talk about them - the point of the step is something the player
# watches happen, and a box arriving on the same frame as the damage talks over it.
func _step_t1_5() -> void:
    if not await _delay_step(POST_HIT_BEAT):
        return
    overlay.set_dim(TutorialOverlay.Dim.FULL)
    # The number in question is a 0, which dice.gd deliberately draws at 40% alpha - so the step
    # explaining it was pointing at something nearly invisible. Fixed by making the digit itself
    # solid for the duration, NOT with a halo behind it (that was tried and looked bad).
    _boost_power_visibility(true)
    overlay.show_info_pointer(_point_above(_power_number_rect()), true)
    overlay.set_text(
        "[center]Nice shot! Playing cards use your [color=red]Power[/color] and set it back to [color=red]0[/color], as you can see here.",
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_6() -> void:
    var intent_rect := _enemy_intent_rect()
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    if intent_rect.size != Vector2.ZERO:
        overlay.show_glow(intent_rect, TutorialOverlay.GLOW_COLOR_THREAT)
        overlay.show_pointer(_point_above(intent_rect), TutorialOverlay.PointerDir.DOWN)
    overlay.set_text(
        "[center]That icon above the enemy is his [color=gold]next move[/color]. He swings the moment you end your turn. Let's do something about it!",
        "near_enemy", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_7() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]You have used your [color=#4a90d9]Blue Dice[/color], but have a [color=red]Red Dice[/color] left. Click here to switch your [color=gold]Active Dice[/color].",
        "near_dice", false)
    overlay.show_pointer(_point_above(_dice_slot_icon_rect("red")), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_dice_slot_icon_rect("red"), DICE_SLOT_PULSE_PAD)
    _apply_gate({"dice_types": ["red"]})
    _wait(Events.active_dice_changed, 1)


# Explains what Red actually IS before asking the player to use it. The old flow jumped
# straight from "click the Red slot" to "drop a card on it", so the card-before-roll reversal -
# the entire point of the Red Dice - was never stated, only demonstrated.
func _step_t1_7b() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center][color=red]Red[/color] works like [color=#4a90d9]Blue[/color], with one twist: you choose the [color=#c896ff]Card[/color] [color=gold]BEFORE[/color] you roll. That makes it far more unpredictable.",
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_8() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Put a [color=#c896ff]Block[/color] Card in the socket here",
        "near_dice", false)
    _lift_card(BLOCK_ID)
    overlay.show_pointer(_point_above(_socket_rect()), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [BLOCK_ID]})
    _wait_card_charged()


func _step_t1_9() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Now roll. Your [color=#c896ff]Block[/color] Card will get played right after.",
        "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.red_dice_rolled)


# The Block payoff gets its own Continue-gated beat before the end-turn prompt. Block was the
# one thing the tutorial made the player DO without ever showing them the result of it: the old
# single step said "his hit is fully covered" while pointing at End Turn, so the badge that
# actually proves it was never looked at. Delayed so the socketed card resolves, the number pops
# on the health bar, and THEN a box arrives to name it.
func _step_t1_10_block() -> void:
    if not await _delay_step(POST_BLOCK_BEAT):
        return
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    var block_rect := _player_block_rect()
    if block_rect.size != Vector2.ZERO:
        overlay.show_glow(block_rect)
        overlay.show_info_pointer(_point_above(block_rect), true)
    overlay.set_text(
        "[center]Great! You gained [color=gold]%d Block[/color], as you can see here. That means you will fully block the Skeleton's attack." % _player_block(),
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_10() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center][color=gold]End your turn[/color]: he takes his, then all your Dice come back.",
        "near_dice", false)
    overlay.show_pointer(_point_above(end_turn_button.get_global_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(end_turn_button.get_global_rect())
    _apply_gate({"end_turn": true})
    _wait_end_turn()


# ---- TURN 2: "Bad luck is a puzzle" -------------------------------------------------

# You keep the same active Dice across a turn boundary, and turn 1 ended on Red (Block was
# socketed there) - so turn 2 opens still on Red, where ROLL does nothing without a socketed
# card. This step makes the player switch back to Blue first (mirrors T1.7's select-red).
# Power is 0 here, so clicking a slot can't trip the type-switch WarningPowerReset popup.
func _step_t2_switch_blue() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Fresh turn, all your Dice are back. You can use them in [color=gold]any order[/color], and almost every Card works with [color=gold]any Dice[/color]. Switch back to [color=#4a90d9]Blue[/color].",
        "near_dice", false)
    overlay.show_pointer(_point_above(_dice_slot_icon_rect("blue")), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_dice_slot_icon_rect("blue"), DICE_SLOT_PULSE_PAD)
    _apply_gate({"dice_types": ["blue"]})
    _wait(Events.active_dice_changed, 1)


func _step_t2_1() -> void:
    Global.tutorial_forced_rolls = [1, 1, 3, 4]
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Good. Now [color=gold]ROLL[/color] your [color=#4a90d9]Blue Dice[/color]!", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_2() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]A 1. Charming. Try the other one.", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_3() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Those were some bad rolls! Fortunately, some [color=#c896ff]Cards[/color] are made for these situations. [color=gold]Hover[/color] on [color=#c896ff]Recombobulate[/color] to read its [color=gold]Refuel[/color] effect, then play it to gain your [color=#4a90d9]Blue Dice[/color] back!",
        "near_dice", false)
    _lift_card(RECOMBOBULATE_ID)
    _apply_gate({"cards": [RECOMBOBULATE_ID]})
    _wait_card_played()
    _pulse_lifted_card()


func _step_t2_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Now please, don't roll a 1 again. [color=gold]Roll![/color]", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_5() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]You might think a 3 is bad. Some [color=#c896ff]Cards[/color] love it. That [color=gold]MAX 3[/color] ribbon on [color=#c896ff]Low Blow[/color] is its [color=red]Power[/color] requirement: low rolls only, and it pays back triple. Look what the card is offering now, then hit him with it!",
        "near_dice", false)
    _lift_card(LOW_BLOW_ID)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [LOW_BLOW_ID]})
    _wait_card_played()
    # The MAX 3 ribbon is what this step's copy is actually ABOUT, and nothing marked it -
    # the player had to work out which strip of the card "that MAX 3 ribbon" meant.
    _pulse_lifted_card(true)


func _step_t2_6() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]He's winding up the same hit again. Let's block it. Roll first.",
        "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_7() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.show_info_pointer(_point_above(_power_number_rect()), true)
    overlay.set_text(
        "[center]%d [color=red]Power[/color], and he hits for [color=gold]6[/color]. No worries, [color=#c896ff]Reinforce[/color] tops your Power [color=gold]up[/color] instead of spending it. Play it!" % Global.roll_value,
        "near_dice", false)
    _lift_card(REINFORCE_ID)
    _apply_gate({"cards": [REINFORCE_ID]})
    _wait_card_played()
    _pulse_lifted_card()


func _step_t2_8() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Perfect. Play a [color=#c896ff]Block[/color] Card to block [color=gold]6[/color].",
        "near_dice", false)
    _lift_card(BLOCK_ID)
    _apply_gate({"cards": [BLOCK_ID]})
    _wait_card_played()
    _pulse_lifted_card()


func _step_t2_9() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    # The spare card here is a Block (player_handler forces a 2nd Block, never a Strike) and
    # no kill is available, so "end turn" reads clean. The copy points forward to the finale
    # WITHOUT implying you hoard the Red Dice - dice don't carry over (Julien flagged that
    # framing), turn 3 hands you a fresh one regardless.
    overlay.set_text(
        "[center]A [color=red]Red Dice[/color] left and nothing worth spending it on. That's fine. But look at this turn: two 1s, and you still landed exactly where you needed. Play it smart and bad luck stops deciding for you. Now [color=gold]end your turn[/color].",
        "near_dice", false)
    overlay.show_pointer(_point_above(end_turn_button.get_global_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(end_turn_button.get_global_rect())
    _apply_gate({"end_turn": true})
    _wait_end_turn()


# ---- TURN 3: "Choose your luck" ----------------------------------------------------
# Rebuilt from a Red-Dice/Scout ritual that read as ceremony (Julien: "the flex here is to
# teach the player to use a scout card on red, like why?"). The player held 2 Blue, a Strike
# and faced a 6 HP enemy, so "roll Blue and hit him" already won - the tutorial was demanding
# precision in a situation that required none, and re-teaching Red's card-first quirk that
# turn 1 had already covered.
#
# Now: no dice switching (turn 2 ended on Blue, stay there), a threat that cannot be absorbed,
# and a Scout hand where NO face wins by Striking - not even the 5. Only the 3, tripled by Low
# Blow, lands exactly 9 on a 9 HP Skeleton. Turn 2 taught that a bad roll can be good; turn 3
# makes the player choose the bad roll on purpose, which is the whole thesis of the game.
#
# The three offered faces are 4 / 3 / 5 (the winner deliberately NOT in the first slot, so the
# player has to read all three) and the hand is Scout 3 + Low Blow + exactly one Strike, padded
# with two inert Blocks - see player_handler.TUTORIAL_HAND_BY_TURN for why Reinforce and
# Recombobulate are kept out of it.
# The losing faces stay at full brightness and are simply unclickable; the affordance is a
# pulsing halo on the winner instead (Julien: dimming them read as "these are broken", not as
# "the tutorial wants that one").

# Split in two: the threat lands on its own beat, then the problem it poses. One box carrying
# "he is winding up", "here is the number", "here is your out" and "here is the catch" was
# doing four jobs at the moment the finale's stakes are supposed to sink in.
func _step_t3_1() -> void:
    _threat_affordances()
    overlay.set_text(
        "[center]Oh no, a massive attack! Thankfully, this is perfect to teach you the last part of this tutorial.",
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


# Both numbers are read live (enemy HP, and the intent's own painted damage) so this copy can
# never drift from what the player is looking at if that swing or the Skeleton's HP is retuned.
func _step_t3_1b() -> void:
    _threat_affordances()
    overlay.set_text(
        "[center]He has [color=gold]%d HP[/color] left. Killing him sounds much easier than blocking his [color=gold]%s damage[/color] hit. But a [color=#c896ff]Strike[/color] only hits for as much [color=red]Power[/color] as you roll, so betting on a high roll is far from a guaranteed kill." % [_enemy_health(), _enemy_intent_damage()],
        "near_dice", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


# Shared by both threat beats: red glow + arrow on the intent icon.
func _threat_affordances() -> void:
    var intent_rect := _enemy_intent_rect()
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    if intent_rect.size != Vector2.ZERO:
        overlay.show_glow(intent_rect, TutorialOverlay.GLOW_COLOR_THREAT)
        overlay.show_pointer(_point_above(intent_rect), TutorialOverlay.PointerDir.DOWN)


func _step_t3_2() -> void:
    # Queued BEFORE the card is played, and that ordering is load-bearing: battle.gd consumes
    # Global.tutorial_forced_scout_faces the instant scout_effect fires, and it connected in its
    # own _ready() so it always runs ahead of the director's step advance. The old code set the
    # faces in the FOLLOWING step - one beat too late - so the finale was showing three RANDOM
    # faces while the copy told the player exactly which one to take.
    Global.tutorial_forced_scout_faces = [4, 3, 5]
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]See this [color=#c896ff]Scout 3[/color] card with this blue background? Its blue frame means [color=#5cb3ff]Celestial[/color]: no [color=red]Power[/color], no Dice, free to play. It shows you what your next roll could be. Once again, [color=gold]hover[/color] on it to know more, then play it!",
        "near_dice", false)
    _lift_card(SCOUT3_ID)
    _apply_gate({"cards": [SCOUT3_ID]})
    _wait(Events.scout_effect, 1)
    _pulse_lifted_card()


func _step_t3_3() -> void:
    overlay.set_dim(TutorialOverlay.Dim.NONE)
    # above_hand, not near_dice: the Scout panel opens top-centre and the hero-speech slot sits
    # right under it. A bottom box leaves all three faces readable.
    overlay.set_text(
        "[center]Three possible rolls. You get to pick one. He has [color=gold]%d HP[/color], so none of them kills with a [color=#c896ff]Strike[/color], not even the 5. But [color=#c896ff]Low Blow[/color] triples a roll of 3 or less. [color=gold]Take the 3.[/color]" % _enemy_health(),
        "above_hand", false)
    _gate_scout_faces(1)
    _wait(Events.next_roll_determined)


func _step_t3_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Your next roll is now a guaranteed [color=gold]3[/color]. Roll it.", "near_dice", false)
    overlay.show_pointer(_point_left_of(_roll_button_rect()), TutorialOverlay.PointerDir.RIGHT)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t3_5() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    # Both numbers read live off the roll that just landed, so this can't drift if the finale's
    # faces or Low Blow's multiplier are ever retuned.
    overlay.set_text(
        "[center]%d [color=red]Power[/color], the lowest roll on offer, and exactly what you needed. [color=#c896ff]Low Blow[/color] turns it into [color=gold]%d damage[/color]. Point it at the Skeleton and finish him!" % [Global.roll_value, Global.roll_value * 3],
        "near_dice", false)
    _lift_card(LOW_BLOW_ID)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [LOW_BLOW_ID]})
    _pulse_lifted_card()
    # Advances on battle_over_screen_requested (see _on_battle_over_screen_requested) rather
    # than card_played - the kill needs the enemy's death animation and END_OF_COMBAT relics
    # to resolve first, and that's also the exact signal battle_over_panel.gd is now skipping
    # its own auto-advance for during the tutorial (see the change there).


# The one beat that gets the title-card treatment besides T1.1, and for the same reason in
# reverse: this is the last thing the tutorial ever says, so it should close the game's
# opening rather than look like one more instruction box. Reusing show_welcome bookends the
# whole tutorial - first panel and last panel share a presentation nothing in between has -
# and inherits its warm dim, decorative title, divider, halo and staged entrance for free.
func _step_t3_6() -> void:
    overlay.set_dim(TutorialOverlay.Dim.FULL, TutorialOverlay.DIM_TINT_WARM)
    # The fight is already won here - skipping the tutorial at this point would soft-lock
    # (the director owns emitting battle_won; a skip would shut the overlay down without
    # ever emitting it), so the skip affordance goes away for this final beat.
    overlay.skip_button.hide()
    # Four beats, deliberately separated: what you just did / what the game is / what's out
    # there / how to find out. Run together as one block this reads as a wall of text at the
    # exact moment the player has stopped being taught and is being sent off.
    #
    # "didn't pick the HIGHEST" and not "didn't JUST pick the highest": the roll actually
    # taken was the lowest of the three on offer, so the "not just X, but Y" shape would
    # credit them for something they pointedly did not do, one line after the whole finale
    # was built around them turning down the 5.
    #
    # Gold is #f2c14e, not the generic step box's "gold" - it's the welcome card's own accent,
    # and the two panels are meant to look like a matched pair.
    overlay.show_welcome(
        "Your Odyssey Begins!",
        "[center]You didn't pick the [color=#f2c14e]highest[/color] roll on offer. You picked the [color=#f2c14e]best one for the situation[/color]." \
        + "\n\nThat is Dice Odyssey: you don't hope for luck, you [color=#f2c14e]make it happen[/color]. And when you can't, you [color=#f2c14e]adapt[/color]." \
        + "\n\nAhead lie other [color=#f2c14e]Dice[/color] with their own faces and effects, and [color=#c896ff]Cards[/color] built to spend their [color=red]Power[/color] in far stranger ways." \
        + "\n\nHover anything (Cards, Dice, Relics, Enemies) to learn more.")
    _apply_gate({})
    overlay.continue_pressed.connect(_on_victory_continue_pressed, CONNECT_ONE_SHOT)


func _on_victory_continue_pressed() -> void:
    Global.tutorial_on = false
    overlay.shutdown()
    Events.battle_won.emit()
