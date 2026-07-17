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
const ENEMY_ARROW_DROP := 34.0

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
var _lifted_card: CardUI

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


func _build_steps() -> void:
    _steps = [
        _step_t1_1, _step_t1_2, _step_t1_3, _step_t1_3b, _step_t1_relic,
        _step_t1_4, _step_t1_5,
        _step_t1_6, _step_t1_7, _step_t1_8, _step_t1_9, _step_t1_10,
        _step_t2_switch_blue,
        _step_t2_1, _step_t2_2, _step_t2_3, _step_t2_4, _step_t2_5,
        _step_t2_6, _step_t2_7, _step_t2_8, _step_t2_9,
        _step_t3_1, _step_t3_2, _step_t3_3, _step_t3_4, _step_t3_5,
        _step_t3_6, _step_t3_7,
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
    _ungate_scout_faces()
    _aim_nudge_timer.stop()


# ---------------------------------------------------------------- Gating

# gate keys: "roll" (bool), "cards" (Array[String] of allowed card ids), "dice_types"
# (Array[String] of allowed dice-interface slot types), "end_turn" (bool).
func _apply_gate(gate: Dictionary) -> void:
    _current_gate = gate
    roll_button.disabled = not gate.get("roll", false)

    var allowed_ids: Array = gate.get("cards", [])
    for card_ui: CardUI in hand.get_children():
        card_ui.disabled = not (card_ui.card and allowed_ids.has(card_ui.card.id))

    var allowed_dice: Array = gate.get("dice_types", [])
    for dtype: String in DiceInterface.DICE_TYPE_TO_NODE:
        var slot: Control = dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE[dtype])
        if slot:
            slot.mouse_filter = Control.MOUSE_FILTER_STOP if allowed_dice.has(dtype) else Control.MOUSE_FILTER_IGNORE

    end_turn_button.disabled = not gate.get("end_turn", false)


func _gate_scout_faces(allowed_index: int) -> void:
    _scout_gated = true
    scout_exit_button.disabled = true
    for i in range(battle.scout_faces.size()):
        var face: Control = battle.scout_faces[i]
        if i != allowed_index:
            face.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ungate_scout_faces() -> void:
    if not _scout_gated:
        return
    _scout_gated = false
    scout_exit_button.disabled = false
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


func _enemy() -> Enemy:
    for child in enemy_handler.get_children():
        if child is Enemy:
            return child
    return null


func _roll_button_rect() -> Rect2:
    return roll_button.get_global_rect()


func _dice_slot_rect(dtype: String) -> Rect2:
    var slot: Control = dice_interface.get(DiceInterface.DICE_TYPE_TO_NODE[dtype])
    return slot.get_global_rect() if slot else Rect2()


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
    Global.tutorial_forced_rolls = []
    Global.tutorial_forced_scout_faces = []
    _reset_between_steps()  # also clears the pending completion-signal wait
    _apply_gate({"roll": true, "cards": _all_card_ids(), "dice_types": DiceInterface.DICE_TYPE_TO_NODE.keys(), "end_turn": true})
    overlay.shutdown()
    # Must be set false BEFORE any further hand draws: _on_player_hand_drawn and the
    # battle_over hook both early-return on this, turning the director inert for the
    # rest of the (now normal) fight.
    Global.tutorial_on = false


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

func _step_t1_1() -> void:
    overlay.set_dim(TutorialOverlay.Dim.FULL)
    overlay.set_text(
        "[center][b]Welcome to Dice Odyssey![/b]\nDown here, luck isn't something that happens to you - it's something you [color=gold]use[/color]. Combat runs on two things: [color=gold]Dice[/color] and [color=purple]Cards[/color].",
        "center", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_2() -> void:
    Global.tutorial_forced_rolls = [4, 3, 6, 6]
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]This is a [color=#4a90d9]Blue Dice[/color]. Click [color=gold]ROLL[/color]!", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t1_3() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.show_glow(_power_number_rect())
    overlay.show_info_pointer(_point_above(_power_number_rect()))
    # The "what is this number" explanation lives in the small note pinned by the Power itself;
    # the hero-speech box stays focused on the action (stack + roll again).
    overlay.show_info_note(
        "[center]This is your [color=red]Power[/color], built from your rolls - spend it to play cards.",
        _power_number_rect())
    overlay.set_text(
        "[center]Same-type Dice [color=gold]STACK[/color] - roll your second [color=#4a90d9]Blue[/color] to pile more on!",
        "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


# Third roll is forced to a 6 - a max roll, which already triggers dice.gd's own gold-flash/
# particle/hit-stop celebration for free, so the buildup caps on the game's best-roll juice
# right before the payoff instead of feeling like a third repeat of the same click.
func _step_t1_3b() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]One more [color=#4a90d9]Blue[/color] left - keep stacking!", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
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


func _step_t1_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]13 [color=red]Power[/color] banked! Now spend it: drag [color=purple]Strike[/color] up and [color=gold]point it AT the Skeleton[/color] - release on him, not on empty air.",
        "above_hand", false)
    _lift_card(STRIKE_ID)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [STRIKE_ID]})
    _wait(Events.card_played, 1)


func _step_t1_5() -> void:
    overlay.set_dim(TutorialOverlay.Dim.FULL)
    overlay.show_glow(_power_number_rect())
    overlay.show_info_pointer(_point_above(_power_number_rect()))
    overlay.set_text(
        "[center]See that? Your [color=red]Power[/color] crashed back to [color=red]0[/color]. Playing a card spends [color=gold]ALL of it[/color] - roll first, build it up, [i]then[/i] strike. That's the heart of every turn.",
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
        "[center]That icon above the Skeleton is his [color=gold]next move[/color]: 6 damage, landing at the end of your turn. Let's do something about it.",
        "near_enemy", true)
    _apply_gate({})
    _wait(overlay.continue_pressed)


func _step_t1_7() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Your [color=#4a90d9]Blue Dice[/color] are spent - but the [color=red]Red Dice[/color] is ready. Red plays backwards: [color=gold]card first, roll after[/color]. Click it.",
        "near_dice", false)
    overlay.show_pointer(_point_above(_dice_slot_rect("red")), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_dice_slot_rect("red"))
    _apply_gate({"dice_types": ["red"]})
    _wait(Events.active_dice_changed, 1)


func _step_t1_8() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Drop your [color=purple]Block[/color] onto the Red Dice. Whatever it rolls becomes your armor.",
        "above_hand", false)
    _lift_card(BLOCK_ID)
    overlay.show_pointer(_point_above(_socket_rect()), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [BLOCK_ID]})
    _wait(Events.card_charged, 1)


func _step_t1_9() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Now [color=gold]ROLL[/color] - and pray. (Kidding. Mostly.)", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.red_dice_rolled)


func _step_t1_10() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]A 6! The Skeleton's hit is fully covered. [color=gold]End your turn[/color] - all your Dice come back every turn.",
        "above_hand", false)
    overlay.show_pointer(_point_above(end_turn_button.get_global_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(end_turn_button.get_global_rect())
    _apply_gate({"end_turn": true})
    _wait(Events.player_turn_started)


# ---- TURN 2: "Bad luck is a puzzle" -------------------------------------------------

# You keep the same active Dice across a turn boundary, and turn 1 ended on Red (Block was
# socketed there) - so turn 2 opens still on Red, where ROLL does nothing without a socketed
# card. This step makes the player switch back to Blue first (mirrors T1.7's select-red).
# Power is 0 here, so clicking a slot can't trip the type-switch WarningPowerReset popup.
func _step_t2_switch_blue() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Fresh turn - all your Dice are back! You're free to play your Dice in [color=gold]any order[/color], and almost every card works on [color=gold]any Dice[/color]. Let me show you something. First, click your [color=#4a90d9]Blue Dice[/color] to switch to it.",
        "near_dice", false)
    overlay.show_pointer(_point_above(_dice_slot_rect("blue")), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_dice_slot_rect("blue"))
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
        "[center]TWO 1s?! Okay, breathe. Bad luck can be [color=gold]undone[/color]: [color=purple]Recombobulate[/color] refuels every Dice you rolled this turn. It resets your Power too - but be honest, you won't miss these 2. Play it!",
        "above_hand", false)
    _lift_card(RECOMBOBULATE_ID)
    _apply_gate({"cards": [RECOMBOBULATE_ID]})
    _wait(Events.card_played, 1)


func _step_t2_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Fresh Dice, clean slate. Roll!", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_5() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]A 3. Not glorious - unless you hold [color=purple]Low Blow[/color]. Its [color=gold]MAX 3[/color] ribbon means it only works at Power 3 or less, dealing 3x3 = [color=gold]9 damage[/color]. Low rolls have their own weapons - aim it at the Skeleton!\n[color=silver]Every ribbon (Min, Max, Even...) tells you what Power a card wants.[/color]",
        "above_hand", false)
    _lift_card(LOW_BLOW_ID)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [LOW_BLOW_ID]})
    _wait(Events.card_played, 1)


func _step_t2_6() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]He's winding up another 6-damage hit. One [color=#4a90d9]Blue[/color] left - roll it.", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.dice_rolled, 2)


func _step_t2_7() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.show_glow(_power_number_rect())
    overlay.show_info_pointer(_point_above(_power_number_rect()))
    overlay.set_text(
        "[center]4 Power. Two short of that 6-damage hit... [color=purple]Reinforce[/color]: +2 Power. And watch the number closely - it goes [color=gold]UP[/color], not back to zero. A precious few cards spare your Power like that.",
        "above_hand", false)
    _lift_card(REINFORCE_ID)
    _apply_gate({"cards": [REINFORCE_ID]})
    _wait(Events.card_played, 1)


func _step_t2_8() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]6 [color=red]Power[/color] - exactly enough. [color=purple]Block[/color] it all.", "above_hand", false)
    _lift_card(BLOCK_ID)
    _apply_gate({"cards": [BLOCK_ID]})
    _wait(Events.card_played, 1)


func _step_t2_9() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    # The spare card here is a Block (player_handler forces a 2nd Block, never a Strike) and
    # no kill is available, so "end turn" reads clean. The copy points forward to the finale
    # WITHOUT implying you hoard the Red Dice - dice don't carry over (Julien flagged that
    # framing), turn 3 hands you a fresh one regardless.
    overlay.set_text(
        "[center]That hit won't land - you're fully covered, and out of [color=#4a90d9]Blue[/color] rolls. He's almost down: one clean hit next turn ends this. [color=gold]End your turn[/color].",
        "above_hand", false)
    overlay.show_pointer(_point_above(end_turn_button.get_global_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(end_turn_button.get_global_rect())
    _apply_gate({"end_turn": true})
    _wait(Events.player_turn_started)


# ---- TURN 3: "Bend fate" (Scout + Celestial + the exact kill) ----------------------

func _step_t3_1() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Last stretch - he's barely standing. Start by picking up your [color=red]Red Dice[/color].", "near_dice", false)
    overlay.show_pointer(_point_above(_dice_slot_rect("red")), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_dice_slot_rect("red"))
    _apply_gate({"dice_types": ["red"]})
    _wait(Events.active_dice_changed, 1)


func _step_t3_2() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text(
        "[center]Notice [color=purple]Scout 3[/color] glowing while everything else is dark? That's a [color=#5cb3ff]Celestial[/color] card - the blue frame means it's [color=gold]free[/color]: no Power, no Dice needed. Play it [color=gold]before[/color] you roll anything.",
        "above_hand", false)
    _lift_card(SCOUT3_ID)
    _apply_gate({"cards": [SCOUT3_ID]})
    _wait(Events.scout_effect, 1)


func _step_t3_3() -> void:
    Global.tutorial_forced_scout_faces = [2, 6, 4]
    overlay.set_dim(TutorialOverlay.Dim.NONE)
    # "above_hand" (bottom) instead of "top": the Scout panel of 3 face options opens at the
    # top-center, and a top box sat right on top of it (Julien: "explanation box is hiding the
    # scout panel; put it lower"). Bottom of the screen leaves the Scout panel fully visible.
    overlay.set_text(
        "[center]The Skeleton has [color=gold]6 HP[/color]. A gambler would pray for a 6. You're not a gambler - the die is showing you [color=gold]three possible futures[/color], and you get to [color=gold]choose[/color]. Take the 6.",
        "above_hand", false)
    _gate_scout_faces(1)
    _wait(Events.next_roll_determined)


func _step_t3_4() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Your next roll is a [color=gold]guaranteed 6[/color] - exactly what you need. Drop [color=purple]Strike[/color] onto the Red Dice.", "above_hand", false)
    _lift_card(STRIKE_ID)
    overlay.show_pointer(_point_above(_socket_rect()), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [STRIKE_ID]})
    _wait(Events.card_charged, 1)


func _step_t3_5() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center][color=gold]ROLL.[/color]", "near_dice", false)
    overlay.show_pointer(_point_above(_roll_button_rect()), TutorialOverlay.PointerDir.DOWN)
    overlay.show_pulse(_roll_button_rect())
    _apply_gate({"roll": true})
    _wait(Events.red_dice_rolled)


func _step_t3_6() -> void:
    overlay.set_dim(TutorialOverlay.Dim.SOFT)
    overlay.set_text("[center]Point at the Skeleton. [color=gold]Finish him.[/color]", "near_enemy", false)
    _highlight_enemy()
    overlay.show_pointer(_enemy_arrow_point(), TutorialOverlay.PointerDir.DOWN)
    _apply_gate({"cards": [STRIKE_ID]})
    # Advances on battle_over_screen_requested (see _on_battle_over_screen_requested) rather
    # than card_played - the kill needs the enemy's death animation and END_OF_COMBAT relics
    # to resolve first, and that's also the exact signal battle_over_panel.gd is now skipping
    # its own auto-advance for during the tutorial (see the change there).


func _step_t3_7() -> void:
    overlay.set_dim(TutorialOverlay.Dim.FULL)
    # The fight is already won here - skipping the tutorial at this point would soft-lock
    # (the director owns emitting battle_won; a skip would shut the overlay down without
    # ever emitting it), so the skip affordance goes away for this final beat.
    overlay.skip_button.hide()
    overlay.set_text(
        "[center]Flawless. You needed [color=gold]exactly a 6[/color] - so you took exactly a 6. That's this game: you don't [color=gold]hope[/color] for luck. You stack it, reroll it, cash in your worst rolls, and when it matters most, you [color=gold]choose[/color] it. Out there you'll find stranger Dice, wilder Cards, and enemies who cheat harder than you do. [color=gold]Hover anything[/color] to learn more.",
        "center", true)
    _apply_gate({})
    overlay.continue_pressed.connect(_on_victory_continue_pressed, CONNECT_ONE_SHOT)


func _on_victory_continue_pressed() -> void:
    Global.tutorial_on = false
    overlay.shutdown()
    Events.battle_won.emit()
