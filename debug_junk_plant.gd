extends Node

# Pins the junk-plant presentation (scenes/ui/junk_plant_presenter.gd): the story of an
# enemy writing a card into one of your piles, told so the player reads WHICH card, HOW
# MANY, and WHERE it went - on the enemy's move.
#
# Sections:
#   A  the timing contract: the enemy's hold (Global.JUNK_PLANT_PRESENT_TIME) IS the
#      presenter's conjure+glide+hold for one card, and the Whisper action reads that
#      constant - plus the caption copy for every shape of batch
#   B  one Slander into the DISCARD from a real enemy position: the pile write happens on the
#      emit (before any visual), one real card face wearing the Hex chrome sits at reading
#      size on the stage under a caption naming the pile, it lands ON the discard button at
#      the contracted time, and NOTHING is left behind afterwards (the leak check runs on a
#      path that never calls any manual cleanup - the scout comet lesson)
#   C  two cards in one frame fan into two faces with a "2x" caption
#   D  the DRAW-pile signal writes into draw_pile and the story goes to the draw button
#   E  no on-screen source (Vector2.ZERO): no face, but the pile still punches
#   F  a plant arriving mid-presentation queues behind it - never two fans on stage
#   G  a same-frame batch split across both piles becomes two presentations
#   H  the REAL Whisper move: lunge, hit, plant, and the Slanderer holds its pose for the
#      whole presentation before walking back
#
# Run (logic - headless is enough, nothing here measures text):
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_junk_plant.tscn
# Run (frames - Movie Maker, windowed):
#   JUNK_MOVIE=1 Godot_v4.3-stable_win64_console.exe --path . res://debug_junk_plant.tscn \
#       --write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720 \
#       --rendering-driver opengl3 --position 2000,2000
#
# NEGATIVE CONTROLS (house rule): see _negative_control_note() at the bottom.

const FIGHT := "res://battles/tier_1_slanderers.tres"
const SLANDER_PATH := "res://characters/warrior/cards/card_slander.tres"
const WHISPER_SCRIPT_PATH := "res://enemies/slanderer/slanderer_whisper_action.gd"
const PRESENTER_SCRIPT := preload("res://scenes/ui/junk_plant_presenter.gd")

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _presenter: Control
var _game_clock := 0.0
var _finished: Array = []
var _landed: Array = []
var _started := 0


func check(check_name: String, ok: bool, detail := "") -> void:
	checks += 1
	var suffix := ("  [" + detail + "]") if detail != "" else ""
	if ok:
		print("PASS  ", check_name, suffix)
	else:
		fails += 1
		print("FAIL  ", check_name, suffix)


func _process(delta: float) -> void:
	# Game time (scaled by hit-stops), the clock every tween in the presentation runs on.
	_game_clock += delta


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	seed(20260902)

	await _boot_battle(FIGHT, 1)
	_presenter = _battle.battle_ui.junk_presenter
	if _presenter == null:
		check("BattleUI owns a junk presenter", false)
		get_tree().quit(1)
		return
	_presenter.presentation_started.connect(func(_c: int, _d: int) -> void: _started += 1)
	_presenter.card_landed.connect(func(pile: CardPileOpener) -> void: _landed.append(pile))
	_presenter.presentation_finished.connect(func(c: int, d: int) -> void: _finished.append([c, d]))

	if OS.get_environment("JUNK_MOVIE") == "1":
		await _movie()
		get_tree().quit()
		return

	_section_a()
	await _section_b()
	await _section_c()
	await _section_d()
	await _section_e()
	await _section_f()
	await _section_g()
	await _section_h()

	print("\n==== JUNK PLANT: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- helpers

func _boot_battle(fight: String, tier: int) -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# Documented harness trap: an HBoxContainer with no Control ancestor collapses to zero size.
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = relic_handler
	_battle.battle_stats = load(fight)
	_battle.act_tier = tier
	relic_handler.add_relic(warrior.starting_relic)

	var before := hands_drawn
	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > before, 15.0)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _wait_game(seconds: float) -> void:
	var start := _game_clock
	while _game_clock - start < seconds:
		await get_tree().process_frame


func _find_enemy(display_name: String) -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.stats != null and enemy.stats.enemy_name == display_name:
			return enemy
	return null


func _faces() -> Array:
	var out: Array = []
	for child in _presenter.get_children():
		# queue_free is end-of-frame: a face/caption freed on the landing frame is still a
		# child when presentation_finished fires (same trap as the corpses in enemy_handler).
		if child is CardMenuUI and not child.is_queued_for_deletion():
			out.append(child)
	return out


func _caption() -> Label:
	for child in _presenter.get_children():
		if child is Label and not child.is_queued_for_deletion():
			return child
	return null


func _ring_count(pile: CardPileOpener) -> int:
	var n := 0
	for child in pile.get_children():
		if child is TextureRect:
			n += 1
	return n


func _new_slander() -> Card:
	return (load(SLANDER_PATH) as Card).duplicate()


func _reset_log() -> void:
	_finished.clear()
	_landed.clear()
	_started = 0


# The visual centre at any scale/tilt. NOT global_position + pivot: on a scaled/rotated
# Control that getter returns the transformed corner, and it was off by a whole pivot at
# conjure scale 0 (which is how the presenter's own bug was caught - see its _to_screen note).
func _face_center(face: Control) -> Vector2:
	return face.position + face.pivot_offset


# ---------------------------------------------------------------- A: contract

func _section_a() -> void:
	print("\n--- A: timing contract + caption copy ---")
	check("presenter is wired to the discard button",
			_presenter.discard_pile_button == _battle.battle_ui.discard_pile_button)
	check("presenter is wired to the draw button",
			_presenter.draw_pile_button == _battle.battle_ui.draw_pile_button)
	var stage_time: float = PRESENTER_SCRIPT.stage_time_for(1)
	check("one card leaves the stage EXACTLY when the enemy's hold ends",
			absf(stage_time - Global.JUNK_PLANT_PRESENT_TIME) < 0.001,
			"stage %.3f vs hold %.3f" % [stage_time, Global.JUNK_PLANT_PRESENT_TIME])
	check("the hold is a readable beat, not a blink", Global.JUNK_PLANT_PRESENT_TIME >= 1.0
			and Global.JUNK_PLANT_PRESENT_TIME <= 2.0)
	var src := FileAccess.get_file_as_string(WHISPER_SCRIPT_PATH)
	check("the Whisper action holds its lunge on the SAME constant",
			src.contains("tween_interval(Global.JUNK_PLANT_PRESENT_TIME)"))
	check("...and no longer on the old flat 0.25s", not src.contains("tween_interval(0.25)"))

	var a := _new_slander()
	var b := _new_slander()
	var other: Card = load("res://characters/warrior/cards/warrior_axe_attack1.tres")
	var discard: int = PRESENTER_SCRIPT.Dest.DISCARD
	var draw: int = PRESENTER_SCRIPT.Dest.DRAW
	check("caption names one card and the pile",
			PRESENTER_SCRIPT.caption_text_for([a], discard) == "Slander added to your Discard pile",
			PRESENTER_SCRIPT.caption_text_for([a], discard))
	check("caption counts identical cards",
			PRESENTER_SCRIPT.caption_text_for([a, b], discard) == "2× Slander added to your Discard pile",
			PRESENTER_SCRIPT.caption_text_for([a, b], discard))
	check("caption falls back to a count for a mixed batch, and names the DRAW pile",
			PRESENTER_SCRIPT.caption_text_for([a, other], draw) == "2 cards added to your Draw pile",
			PRESENTER_SCRIPT.caption_text_for([a, other], draw))


# ---------------------------------------------------------------- B: one card, discard

func _section_b() -> void:
	print("\n--- B: one Slander into the DISCARD, from a real enemy ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	check("a Slanderer is on the field", sl != null)
	if sl == null:
		return
	var origin: Vector2 = sl.sprite_2d.global_position
	var discard_button := _battle.battle_ui.discard_pile_button
	var before: int = _battle.char_stats.discard.cards.size()
	var card := _new_slander()
	var t_emit := _game_clock
	Events.add_card_to_discard_requested.emit(card, origin)
	check("the pile write happens on the emit, before any visual",
			_battle.char_stats.discard.cards.size() == before + 1)
	check("no face on the emit frame (one frame of batching)", _faces().is_empty())
	await get_tree().process_frame
	await get_tree().process_frame
	var faces := _faces()
	check("exactly one card face is born", faces.size() == 1, "%d faces" % faces.size())
	if faces.is_empty():
		return
	var face: CardMenuUI = faces[0]
	check("it is the real card: title reads its name", face.title.text == "Slander", face.title.text)
	check("it wears the Hex chrome (frame)", face.card_frame.get_theme_stylebox("panel") == face.HEX_STYLEBOX)
	check("it wears the Hex chrome (banner)", face.card_banner.get_theme_stylebox("panel") == face.HEX_BANNER_STYLEBOX)
	check("born small at the enemy (conjure in progress)", face.scale.x < 0.7, "scale %.2f" % face.scale.x)
	# The origin is a WORLD position; the presenter converts it through the battle camera's
	# canvas transform into BattleUI screen space, so the comparison has to as well.
	var origin_screen: Vector2 = get_viewport().get_canvas_transform() * origin
	check("...and near the source position (world -> screen converted)",
			_face_center(face).distance_to(origin_screen) < 40.0,
			"%.0fpx from source; camera offset %s" % [_face_center(face).distance_to(origin_screen),
					str(get_viewport().get_canvas_transform().origin)])
	check("nothing in the flight is clickable", face.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and face.get_node("Visuals").mouse_filter == Control.MOUSE_FILTER_IGNORE)

	await _wait_game(0.55)
	check("at reading size on the stage after the glide",
			absf(face.scale.x - PRESENTER_SCRIPT.HOLD_SCALE_BY_COUNT[0]) < 0.03, "scale %.2f" % face.scale.x)
	check("parked on the stage spot",
			_face_center(face).distance_to(PRESENTER_SCRIPT.STAGE_CENTER) < 12.0,
			"%.0fpx off" % _face_center(face).distance_to(PRESENTER_SCRIPT.STAGE_CENTER))
	# What is DRAWN, not what position says: the root is a CenterContainer, and anything that
	# grows its minimum size (the aura did, once) re-centres the card body away from the pivot
	# while position+pivot stays put. get_global_rect() is scale-aware (measured 2026-08-28).
	var frame_rect: Rect2 = face.get_node("Visuals/CardBackground/CardFrame").get_global_rect()
	check("the drawn card body is centred where the pivot says",
			frame_rect.get_center().distance_to(_face_center(face)) < 4.0,
			"body centre %s vs pivot centre %s" % [str(frame_rect.get_center()), str(_face_center(face))])
	check("the face root kept its card size (no child grew the container)",
			face.size.is_equal_approx(PRESENTER_SCRIPT.CARD_SIZE), str(face.size))
	var caption := _caption()
	check("a caption is up", caption != null)
	if caption != null:
		check("caption: 'Slander added to your Discard pile'",
				caption.text == "Slander added to your Discard pile", caption.text)
		var card_bottom: float = _face_center(face).y + face.pivot_offset.y * face.scale.y
		check("caption sits BELOW the card, not over it", caption.position.y >= card_bottom - 2.0,
				"caption y %.0f vs card bottom %.0f" % [caption.position.y, card_bottom])
		check("caption is horizontally centred on the card",
				absf((caption.position.x + caption.size.x / 2.0) - _face_center(face).x) < 3.0)

	await _await_until(func() -> bool: return _finished.size() >= 1, 6.0)
	check("the presentation finished", _finished.size() == 1)
	check("it landed on the DISCARD button", _landed.size() == 1 and _landed[0] == discard_button)
	if _finished.size() == 1:
		check("finished for 1 card into the discard",
				_finished[0][0] == 1 and _finished[0][1] == PRESENTER_SCRIPT.Dest.DISCARD)
	# Timing pin: emit -> land = the enemy's hold + the exit streak, measured in GAME time.
	var expected: float = Global.JUNK_PLANT_PRESENT_TIME + PRESENTER_SCRIPT.EXIT_TIME
	var got: float = _game_clock - t_emit - PRESENTER_SCRIPT.CAPTION_FADE
	check("landed when the enemy's hold + exit says (game time)",
			absf(got - expected) < 0.15, "%.2fs vs %.2fs" % [got, expected])

	# LEAK CHECK on a path that calls NO manual cleanup: everything must free itself.
	check("no face left on stage", _faces().is_empty())
	check("no caption left", _caption() == null)
	await _wait_game(0.9)
	check("presenter is empty once the motes and bloom have died",
			_presenter.get_child_count() == 0, "%d children" % _presenter.get_child_count())
	check("the pile ring freed itself", _ring_count(discard_button) == 0,
			"%d rings" % _ring_count(discard_button))


# ---------------------------------------------------------------- C: a fan of two

func _section_c() -> void:
	print("\n--- C: two cards in one frame fan together ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	var origin: Vector2 = sl.sprite_2d.global_position
	var before: int = _battle.char_stats.discard.cards.size()
	Events.add_card_to_discard_requested.emit(_new_slander(), origin)
	Events.add_card_to_discard_requested.emit(_new_slander(), origin)
	check("both written on the emit", _battle.char_stats.discard.cards.size() == before + 2)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_game(0.55)
	var faces := _faces()
	check("two faces on stage", faces.size() == 2, "%d faces" % faces.size())
	check("ONE presentation, not two", _started == 1, "%d started" % _started)
	if faces.size() == 2:
		var dx: float = absf(_face_center(faces[0]).x - _face_center(faces[1]).x)
		var expected_dx: float = PRESENTER_SCRIPT.FAN_SPACING * PRESENTER_SCRIPT.HOLD_SCALE_BY_COUNT[1]
		check("fanned side by side", absf(dx - expected_dx) < 6.0, "dx %.0f vs %.0f" % [dx, expected_dx])
		check("both at the two-card reading size",
				absf(faces[0].scale.x - PRESENTER_SCRIPT.HOLD_SCALE_BY_COUNT[1]) < 0.03)
		# The die's panel starts at x=521; the fan's right edge may kiss its rounded corner but
		# never sit on the ROLL plate (the first numbers put it 54px in, seen on the strip).
		var right_edge: float = maxf(_face_center(faces[0]).x, _face_center(faces[1]).x) + 70.0 * faces[0].scale.x
		check("the fan's right edge stays off the ROLL plate", right_edge < 545.0, "right edge %.0f" % right_edge)
	var caption := _caption()
	check("caption counts them: '2× Slander added to your Discard pile'",
			caption != null and caption.text == "2× Slander added to your Discard pile",
			caption.text if caption else "<none>")
	await _await_until(func() -> bool: return _finished.size() >= 1, 6.0)
	check("two catches on the pile", _landed.size() == 2, "%d landed" % _landed.size())
	check("finished as one presentation of 2", _finished.size() == 1 and _finished[0][0] == 2)
	await _wait_game(0.9)
	check("clean afterwards", _presenter.get_child_count() == 0, "%d children" % _presenter.get_child_count())


# ---------------------------------------------------------------- D: draw pile

func _section_d() -> void:
	print("\n--- D: the DRAW-pile signal ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	var origin: Vector2 = sl.sprite_2d.global_position
	var draw_button := _battle.battle_ui.draw_pile_button
	var before_draw: int = _battle.char_stats.draw_pile.cards.size()
	var before_discard: int = _battle.char_stats.discard.cards.size()
	var card := _new_slander()
	Events.add_card_to_draw_pile_requested.emit(card, origin)
	check("draw pile grew by 1 on the emit", _battle.char_stats.draw_pile.cards.size() == before_draw + 1)
	check("the discard was not touched", _battle.char_stats.discard.cards.size() == before_discard)
	check("the card is IN the draw pile", _battle.char_stats.draw_pile.cards.has(card))
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_game(0.55)
	var caption := _caption()
	check("caption names the DRAW pile", caption != null and caption.text == "Slander added to your Draw pile",
			caption.text if caption else "<none>")
	await _await_until(func() -> bool: return _finished.size() >= 1, 6.0)
	check("it landed on the DRAW button", _landed.size() == 1 and _landed[0] == draw_button)
	if _finished.size() == 1:
		check("finished with dest DRAW", _finished[0][1] == PRESENTER_SCRIPT.Dest.DRAW)
	await _wait_game(0.9)
	check("clean afterwards", _presenter.get_child_count() == 0)
	check("the draw button's ring freed itself", _ring_count(draw_button) == 0)


# ---------------------------------------------------------------- E: no source

func _section_e() -> void:
	print("\n--- E: no on-screen source (Vector2.ZERO) ---")
	_reset_log()
	var discard_button := _battle.battle_ui.discard_pile_button
	var before: int = _battle.char_stats.discard.cards.size()
	Events.add_card_to_discard_requested.emit(_new_slander(), Vector2.ZERO)
	check("still written", _battle.char_stats.discard.cards.size() == before + 1)
	await get_tree().process_frame
	await get_tree().process_frame
	check("no face is born", _faces().is_empty())
	check("no presentation started", _started == 0)
	check("finished immediately", _finished.size() == 1)
	check("but the pile still punched", discard_button.scale.x > 1.0, "scale %.2f" % discard_button.scale.x)
	await _wait_game(0.4)


# ---------------------------------------------------------------- F: queueing

func _section_f() -> void:
	print("\n--- F: a plant mid-presentation waits its turn ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	var origin: Vector2 = sl.sprite_2d.global_position
	Events.add_card_to_discard_requested.emit(_new_slander(), origin)
	await _wait_game(0.45)
	Events.add_card_to_discard_requested.emit(_new_slander(), origin)
	await get_tree().process_frame
	await get_tree().process_frame
	check("the presenter is busy", _presenter.is_presenting())
	check("only ONE face on stage while the first plays", _faces().size() == 1, "%d faces" % _faces().size())
	check("only one presentation started so far", _started == 1)
	await _await_until(func() -> bool: return _finished.size() >= 2, 10.0)
	check("both presentations played, one after the other", _finished.size() == 2 and _started == 2)
	check("two catches", _landed.size() == 2)
	await _wait_game(0.9)
	check("clean afterwards", _presenter.get_child_count() == 0)


# ---------------------------------------------------------------- G: mixed piles

func _section_g() -> void:
	print("\n--- G: one frame, both piles ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	var origin: Vector2 = sl.sprite_2d.global_position
	Events.add_card_to_discard_requested.emit(_new_slander(), origin)
	Events.add_card_to_draw_pile_requested.emit(_new_slander(), origin)
	await _await_until(func() -> bool: return _finished.size() >= 2, 10.0)
	check("split into two presentations (one caption can only name one pile)",
			_finished.size() == 2 and _started == 2, "%d finished" % _finished.size())
	if _finished.size() == 2:
		var dests := [_finished[0][1], _finished[1][1]]
		check("one went to each pile",
				dests.has(PRESENTER_SCRIPT.Dest.DRAW) and dests.has(PRESENTER_SCRIPT.Dest.DISCARD))
	check("landed on both buttons", _landed.size() == 2
			and _landed.has(_battle.battle_ui.draw_pile_button)
			and _landed.has(_battle.battle_ui.discard_pile_button))
	await _wait_game(0.9)
	check("clean afterwards", _presenter.get_child_count() == 0)


# ---------------------------------------------------------------- H: the real move

func _section_h() -> void:
	print("\n--- H: the real Whisper - the Slanderer holds still while you read ---")
	_reset_log()
	var sl := _find_enemy("Slanderer")
	if sl == null:
		check("Slanderer found", false)
		return
	# Slanderer A opens on Whisper (forced_opener_action_id); re-pick on turn 0 to be sure.
	Global.fight_turn = 0
	sl.last_action = ""
	sl.last_action_count = 0
	sl.update_action()
	check("the opener is the Whisper", sl.current_action != null
			and sl.current_action.action_id == "slanderer_whisper",
			sl.current_action.action_id if sl.current_action else "<none>")
	if sl.current_action == null or sl.current_action.action_id != "slanderer_whisper":
		return
	var home: Vector2 = sl.global_position
	var before: int = _battle.char_stats.discard.cards.size()
	var t_plant := -1.0
	var t_return := -1.0
	var lunge_x := INF
	sl.do_turn()
	var t0 := _game_clock
	while _game_clock - t0 < 4.0:
		await get_tree().process_frame
		if t_plant < 0.0 and _battle.char_stats.discard.cards.size() > before:
			t_plant = _game_clock
			lunge_x = sl.global_position.x
		elif t_plant >= 0.0 and t_return < 0.0 and sl.global_position.x > lunge_x + 0.05:
			t_return = _game_clock
		if t_return >= 0.0 and _finished.size() >= 1 and sl.global_position.distance_to(home) < 2.0:
			break
	check("the Whisper planted a card", t_plant >= 0.0)
	check("a presentation played for it", _started == 1 and _finished.size() == 1)
	if t_plant >= 0.0 and t_return >= 0.0:
		var held := t_return - t_plant
		check("the Slanderer held its lunge for the presentation (game time)",
				absf(held - Global.JUNK_PLANT_PRESENT_TIME) < 0.12,
				"held %.2fs vs %.2fs" % [held, Global.JUNK_PLANT_PRESENT_TIME])
	else:
		check("the Slanderer walked back", false)
	check("...and is back home", sl.global_position.distance_to(home) < 2.0,
			"%.1fpx off" % sl.global_position.distance_to(home))
	check("landed on the DISCARD", _landed.size() == 1 and _landed[0] == _battle.battle_ui.discard_pile_button)
	await _wait_game(0.9)
	check("clean afterwards", _presenter.get_child_count() == 0)


# ---------------------------------------------------------------- movie

# Frames for the eye: the real Whisper (lunge, hit, plant, hold, return) and then a two-card
# fan into the DRAW pile from the other Slanderer's spot.
func _movie() -> void:
	await _wait_game(0.6)
	var sl := _find_enemy("Slanderer")
	Global.fight_turn = 0
	sl.last_action = ""
	sl.last_action_count = 0
	sl.update_action()
	print("[movie] whisper at clock %.2f, engine frame %d" % [_game_clock, Engine.get_process_frames()])
	sl.do_turn()
	await _wait_game(3.4)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var other: Enemy = enemies[enemies.size() - 1]
	var origin: Vector2 = other.sprite_2d.global_position
	print("[movie] fan of 2 to the DRAW pile at clock %.2f, engine frame %d" % [_game_clock, Engine.get_process_frames()])
	Events.add_card_to_draw_pile_requested.emit(_new_slander(), origin)
	Events.add_card_to_draw_pile_requested.emit(_new_slander(), origin)
	await _wait_game(3.2)


# NEGATIVE CONTROLS, for whoever touches this next:
#   1. Drop the `t.tween_callback(ui.queue_free)` at the end of the exit in
#      junk_plant_presenter.gd -> B's "no face left on stage" + "presenter is empty" go red
#      (and the card would park, dead, on the discard button in play).
#   2. Put the Whisper's tween_interval back to 0.25 -> A's two contract checks and H's hold
#      go red.
#   3. Make _flush_pending() queue each entry as its own batch -> C's "ONE presentation" and
#      the "2×" caption go red.
#   4. Swap the pile in _pile_for() -> D's "landed on the DRAW button" goes red.
