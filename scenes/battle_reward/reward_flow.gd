extends RefCounted

# Win -> rewards flow (2026-09-24).
#
# Julien asked how to improve the reward screen and the transition to it. Nine ideas were
# built behind a preview switch, filmed, and adopted as a whole the same day, with two
# changes of his: the screen leaves on its own once every reward is taken (no Continue to
# press), and Continue warns when a card reward was never even opened.
#
# No class_name, preloaded where needed (battle.gd, battle_over_panel.gd, run.gd,
# battle_reward.gd) - the capture_rig.gd / card_send_off.gd convention, so nothing needs a
# class-cache rescan and no live editor has a new type to trip over.
#
# Numbering = the proposal message:
#   1 rewards over the live room       run.gd::_show_reward_view + battle_reward.gd
#   2 clear the table at the win        begin_victory() below
#   3 hero victory pose                 on_win() below
#   4 audio: music fades, the jingle rings on the win, map music under the rewards
#   5 loot coins dropped by the last kill, flown into the gold row
#   6 claimed gold flies to the counter, counter counts on arrival, row folds away
#   7 Skip keeps the card row           battle_reward.gd
#   8 every reward taken: the screen leaves on its own   battle_reward.gd
#   9 boss card row reads "Add a Rare Card" with a gold rim   battle_reward.gd
#
# The tutorial fight goes through the same win beat. Its director only owns WHEN the rewards
# open (battle_over_panel.gd waits for its last panel), not what the room does meanwhile.
#
# When there is no room to sit over (run.gd::_show_reward_view falls back to the old swap),
# the reward screen keeps the two one-line fixes: its background is opaque from the first
# frame (no grey frame) and uses the fight's own framing and grade (no zoom jump).

# --- Idea 1 -----------------------------------------------------------------------------
# The reward screen is pushed on its own CanvasLayer over the fight: above BattleUI (1),
# below the TopBar (3), so the relic bar and gold stay on top exactly as today. A plain
# Control in the base canvas would not do: battle nodes carry z_index up to 60 (power orbs,
# ROLL 12), and z_index sorts across the whole canvas.
const OVERLAY_LAYER := 2
# Today's dimmer is 0.70 black over a copy of the background. Over the live room the hero
# is the point, so it stays readable underneath.
const OVERLAY_DIM := 0.5

# --- Idea 2 -----------------------------------------------------------------------------
const VICTORY_META := "reward_flow_victory"
# Lets the killing blow and its hit-stop read before anything starts leaving.
const TABLE_CLEAR_DELAY := 0.25
# STS2's hand anim-out is 500px over 0.8s with BACK ease-in at 1080p (NPlayerHand.cs).
const HAND_DROP := 330.0
const HAND_DROP_TIME := 0.55
const SIDE_SLIDE := 280.0
const PILE_DROP := 170.0
const SIDE_SLIDE_TIME := 0.45
const DICE_SINK := 40.0
const DICE_FADE_TIME := 0.5

# --- Idea 4 -----------------------------------------------------------------------------
const MUSIC_FADE_DELAY := 0.3
const MUSIC_FADE_TIME := 0.9
const JINGLE := preload("res://success.mp3")
const JINGLE_VOLUME_DB := -3.0
# Replaces battle_over_panel.gd's WIN_AUTO_ADVANCE_DELAY (0.7s of nothing today). The flex
# and the jingle now fill the beat, so the rewards can come sooner.
# 0.5 lets the flex (0.63s) finish before the dimmer comes down over the room.
const WIN_DELAY := 0.5
# The map music comes in under the reward screen once the jingle has rung out, instead of
# the screen sitting silent until Continue.
const MAP_MUSIC_DELAY := 1.5
const MAP_MUSIC_FADE_IN := 1.6
const MAP_MUSIC_START_DB := -30.0

# --- Ideas 5 and 6 ----------------------------------------------------------------------
const COIN_TEXTURE := preload("res://gold_icon_v2.png")
# PLACEHOLDER sounds, both already in the project.
const COIN_TINK := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const COIN_DROP := preload("res://gold_pickup_sound.mp3")
# Above the reward overlay (2) and the TopBar (3) so a coin can land ON the gold counter,
# below tooltips (100) and the transition curtain (110).
const FLIGHT_LAYER := 96
const LOOT_COIN_SIZE := 26.0
const LOOT_COUNT_MIN := 5
const LOOT_COUNT_MAX := 8
const LOOT_SPREAD_X := 90.0
const LOOT_APEX_MIN := 70.0
const LOOT_APEX_MAX := 150.0
const LOOT_FALL_TIME := 0.5
const LOOT_START_DELAY := 0.12
const GOLD_COIN_SIZE := 24.0
const GOLD_COINS_MIN := 5
const GOLD_COINS_MAX := 14
const GOLD_BURST_TIME := 0.12
const GOLD_FLIGHT_MIN := 0.45
const GOLD_FLIGHT_MAX := 0.62
const GOLD_STAGGER := 0.035

# Set on the win beat, consumed by the reward screen so the jingle plays once. run.gd clears
# it at every run start, so a win beat cut short by a quit can't mute the next run's jingle.
static var jingle_played := false
# Coins resting on the floor where the last enemy died, waiting for the gold row.
static var loot_coins: Array = []
# The fight's background grade (battle_background.gdshader), for the swap fallback.
static var last_bg_material: Material = null


# =========================================================================================
# The win beat (ideas 2-5), driven by battle.gd
# =========================================================================================

# Called on the frame the last enemy dies, while its body is still dissolving.
static func begin_victory(battle: Node, enemy: Node) -> void:
    if battle.has_meta(VICTORY_META):
        return
    battle.set_meta(VICTORY_META, true)
    jingle_played = false
    var ui: Node = battle.get_node_or_null("BattleUI")
    if ui != null:
        _lock_combat_input(ui)
        _clear_table(battle, ui)
    _drop_loot(battle, enemy)
    _fade_out_music(battle)


static func is_victory(battle: Node) -> bool:
    return battle.has_meta(VICTORY_META)


# The corpse is gone (battle.gd's END_OF_COMBAT beat): the hero celebrates and the jingle
# rings here, instead of 0.7s later over a screen swap.
static func on_win(battle: Node) -> void:
    var player: Node = battle.get_node_or_null("Player")
    if player != null and player.has_method("play_flex"):
        player.play_flex()
    SFXPlayer.play(JINGLE, false, 1.0, JINGLE_VOLUME_DB, 1)
    jingle_played = true


static func _lock_combat_input(ui: Node) -> void:
    # Clicks would otherwise still reach the hand, End Turn and the dice during the ~1.4s the
    # last body takes to dissolve. End Turn there threw the whole hand away and dimmed the
    # dice under the victory (filmed 2026-09-24).
    var blocker := Control.new()
    blocker.name = "VictoryInputBlocker"
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.add_child(blocker)
    var end_turn := ui.get_node_or_null("EndTurnButton") as Button
    if end_turn != null:
        end_turn.disabled = true
    if ui.has_method("_stop_end_turn_highlight"):
        ui.call("_stop_end_turn_highlight")


static func _clear_table(battle: Node, ui: Node) -> void:
    var t := battle.create_tween().set_parallel(true)
    var hand := ui.get_node_or_null("Hand") as Control
    if hand != null:
        t.tween_property(hand, "position:y", hand.position.y + HAND_DROP, HAND_DROP_TIME) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(TABLE_CLEAR_DELAY)
    var end_turn := ui.get_node_or_null("EndTurnButton") as Control
    if end_turn != null:
        var delay := TABLE_CLEAR_DELAY + 0.05
        t.tween_property(end_turn, "position:x", end_turn.position.x + SIDE_SLIDE, SIDE_SLIDE_TIME) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
        t.tween_property(end_turn, "modulate:a", 0.0, SIDE_SLIDE_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(delay)
    for pile_name: String in ["DrawPileButton", "DiscardPileButton", "ExhaustPileButton", "DeckPileButton"]:
        var pile := ui.get_node_or_null(pile_name) as Control
        if pile == null or not pile.visible:
            continue
        var delay := TABLE_CLEAR_DELAY + 0.08
        t.tween_property(pile, "position:y", pile.position.y + PILE_DROP, SIDE_SLIDE_TIME) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
        t.tween_property(pile, "modulate:a", 0.0, SIDE_SLIDE_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(delay)
    # The dice cluster sinks and fades. battle.gd's turn dim writes the same roots' modulate,
    # so it is killed first and told to stay out (see battle.gd::_tween_player_action_ui).
    var dim_tween: Variant = battle.get("_dim_tween")
    if dim_tween is Tween and (dim_tween as Tween).is_valid():
        (dim_tween as Tween).kill()
    for root_name: String in ["ActiveDice", "DiceInterface"]:
        var root := battle.get_node_or_null(root_name) as CanvasItem
        if root == null:
            continue
        var start_y: float = root.get("position").y
        var delay := TABLE_CLEAR_DELAY + 0.1
        t.tween_property(root, "position:y", start_y + DICE_SINK, DICE_FADE_TIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(delay)
        t.tween_property(root, "modulate:a", 0.0, DICE_FADE_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(delay)


static func _fade_out_music(battle: Node) -> void:
    var music := battle.get_tree().root.get_node_or_null("MusicPlayer")
    if music == null:
        return
    for child: Node in music.get_children():
        var player := child as AudioStreamPlayer
        if player == null or not player.playing:
            continue
        # MusicPlayer.play() re-sets volume_db on every call, so the next fight's music can
        # never inherit this -48.
        var t := player.create_tween()
        t.tween_interval(MUSIC_FADE_DELAY)
        t.tween_property(player, "volume_db", -48.0, MUSIC_FADE_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        t.tween_callback(player.stop)


# =========================================================================================
# Coins (ideas 5 and 6)
# =========================================================================================

static func make_coin(size: float) -> Sprite2D:
    var coin := Sprite2D.new()
    coin.texture = COIN_TEXTURE
    var s := size / float(COIN_TEXTURE.get_width())
    coin.scale = Vector2(s, s)
    return coin


static func flight_layer(tree: SceneTree) -> CanvasLayer:
    var existing := tree.root.get_node_or_null("RewardFlowFlight") as CanvasLayer
    if existing != null:
        return existing
    var layer := CanvasLayer.new()
    layer.name = "RewardFlowFlight"
    layer.layer = FLIGHT_LAYER
    tree.root.add_child(layer)
    return layer


static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
    return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


# Idea 5, part 1: the last body spills coins that land on the floor at its feet.
static func _drop_loot(battle: Node, enemy: Node) -> void:
    loot_coins.clear()
    if enemy == null or not is_instance_valid(enemy):
        return
    var origin: Vector2 = Card.thrown_impact_pos(enemy)
    # The health bar sits on the feet line (enemy.gd places StatsUI there). It is hidden at
    # death but keeps its rect.
    var floor_y := origin.y + 90.0
    var stats_ui := enemy.get_node_or_null("StatsUI") as Control
    if stats_ui != null:
        floor_y = stats_ui.get_global_rect().position.y - 6.0
    var count := randi_range(LOOT_COUNT_MIN, LOOT_COUNT_MAX)
    for i in count:
        var coin := make_coin(LOOT_COIN_SIZE * randf_range(0.9, 1.1))
        coin.z_index = 12
        coin.position = origin
        coin.modulate.a = 0.0
        battle.add_child(coin)
        loot_coins.append(coin)
        var land := Vector2(origin.x + randf_range(-LOOT_SPREAD_X, LOOT_SPREAD_X),
            floor_y + randf_range(-4.0, 8.0))
        var apex := Vector2((origin.x + land.x) / 2.0, origin.y - randf_range(LOOT_APEX_MIN, LOOT_APEX_MAX))
        var t := coin.create_tween()
        t.tween_interval(LOOT_START_DELAY + i * 0.03)
        t.tween_property(coin, "modulate:a", 1.0, 0.06)
        var fall_time := LOOT_FALL_TIME * randf_range(0.85, 1.15)
        t.tween_method(func(v: float) -> void: coin.position = bezier(origin, apex, land, v), 0.0, 1.0, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        # One small bounce, then it rests.
        t.tween_property(coin, "position:y", land.y - 14.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        t.tween_property(coin, "position:y", land.y, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    SFXPlayer.play(COIN_DROP, false, 1.25, -8.0)


# Idea 5, part 2: the resting coins lift off the floor and land in the gold row as it pops in.
static func fly_loot_to(tree: SceneTree, target: Vector2, delay: float, on_arrive: Callable) -> void:
    var live: Array = []
    for coin: Variant in loot_coins:
        if is_instance_valid(coin):
            live.append(coin)
    loot_coins.clear()
    if live.is_empty():
        return
    var layer := flight_layer(tree)
    for i in live.size():
        var coin := live[i] as Node2D
        # Screen position BEFORE leaving the fight's canvas; the flight layer is screen space.
        var screen: Vector2 = coin.get_global_transform_with_canvas().origin
        coin.get_parent().remove_child(coin)
        layer.add_child(coin)
        coin.position = screen
        coin.z_index = 0
        var apex := Vector2((screen.x + target.x) / 2.0, minf(screen.y, target.y) - 120.0)
        var t := coin.create_tween()
        t.tween_interval(delay + i * 0.04)
        var lift_time := randf_range(0.42, 0.55)
        t.tween_method(func(v: float) -> void: coin.position = bezier(screen, apex, target, v), 0.0, 1.0, lift_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        t.tween_callback(on_arrive.bind(i))
        t.tween_callback(coin.queue_free)


# Idea 6: the claimed gold flies from its row to the top-bar counter. on_arrive(i) fires per
# coin; the caller starts the counter on the first one ("count on arrival"). Returns how long
# until the payout has settled (last coin landed AND the counter done counting from the first
# one), or 0.0 when nothing flew.
static func fly_gold_to_counter(tree: SceneTree, from: Vector2, amount: int, on_arrive: Callable) -> float:
    var counter_icon := gold_counter_icon(tree)
    if counter_icon == null:
        return 0.0
    var target := counter_icon.get_global_rect().get_center()
    var count := clampi(roundi(amount / 5.0), GOLD_COINS_MIN, GOLD_COINS_MAX)
    var layer := flight_layer(tree)
    var first_landing := INF
    var last_landing := 0.0
    for i in count:
        var coin := make_coin(GOLD_COIN_SIZE * randf_range(0.9, 1.1))
        coin.position = from
        layer.add_child(coin)
        var burst := from + Vector2(randf_range(-46.0, 46.0), randf_range(-38.0, 20.0))
        var apex := Vector2(lerpf(burst.x, target.x, 0.35), minf(burst.y, target.y) - randf_range(40.0, 110.0))
        var t := coin.create_tween()
        t.tween_interval(i * GOLD_STAGGER)
        t.tween_property(coin, "position", burst, GOLD_BURST_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        var fly_time := randf_range(GOLD_FLIGHT_MIN, GOLD_FLIGHT_MAX)
        t.tween_method(func(v: float) -> void: coin.position = bezier(burst, apex, target, v), 0.0, 1.0, fly_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        t.tween_callback(on_arrive.bind(i))
        t.tween_callback(coin.queue_free)
        var landing := i * GOLD_STAGGER + GOLD_BURST_TIME + fly_time
        first_landing = minf(first_landing, landing)
        last_landing = maxf(last_landing, landing)
    return maxf(last_landing, first_landing + GoldUI.COUNT_DURATION)


static func gold_counter_icon(tree: SceneTree) -> Control:
    var gold_ui := tree.root.find_child("GoldUI", true, false)
    if gold_ui == null:
        return null
    for child: Node in gold_ui.get_children():
        if child is TextureRect:
            return child as Control
    return gold_ui as Control


# A brightness flash, not a scale punch: the gold icon and the reward-row icon are container
# children, and a container resets its children's scale on its next sort (the count-up
# changes the label width, which re-sorts every frame).
static func flash(node: CanvasItem, strength := 1.6) -> void:
    if node == null or not is_instance_valid(node):
        return
    var t := node.create_tween()
    t.tween_property(node, "modulate", Color(strength, strength * 0.92, strength * 0.75, 1.0), 0.05)
    t.tween_property(node, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func play_tink(index: int) -> void:
    SFXPlayer.play(COIN_TINK, false, 1.7 + index * 0.04, -11.0, -1)


# =========================================================================================
# The pulsing ring behind Continue when only skipped card rows are left (the End Turn
# "nothing left to do" ring)
# =========================================================================================

static func attach_pulse_ring(button: Control) -> void:
    if button.get_node_or_null("RewardFlowRing") != null:
        return
    var ring := TextureRect.new()
    ring.name = "RewardFlowRing"
    ring.texture = DicePalette.glow_texture()
    ring.material = DicePalette.additive_material()
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.show_behind_parent = true
    var ring_size := Vector2(300.0, 300.0)
    ring.size = ring_size
    ring.pivot_offset = ring_size / 2.0
    ring.position = button.size / 2.0 - ring_size / 2.0
    ring.modulate = Color(1, 1, 1, 0)
    button.add_child(ring)
    var gold := Color(1.0, 0.82, 0.35, 0.6)
    # The reset is two ZERO-LENGTH property steps, not a tween_callback: a lambda created
    # inside a static function never fires as a tween_callback in Godot 4.3 (measured with
    # debug_ring_probe - the ring stayed at alpha 0), although the same kind of lambda works
    # in tween_method.
    var t := ring.create_tween().set_loops()
    t.tween_property(ring, "scale", Vector2(0.45, 0.45), 0.0)
    t.parallel().tween_property(ring, "modulate", gold, 0.0)
    t.tween_property(ring, "scale", Vector2(0.8, 0.8), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(ring, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
