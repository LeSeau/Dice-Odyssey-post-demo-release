class_name Battle
extends Node2D

var initialized= false
const RUN_SCENE = preload("res://scenes/run/run.tscn")

# --- Act 2 runtime scaling (placeholder) ----------------------------------
# Act 2 recycles act-1 fights (run.gd draws them from higher act-1 pools); the
# recycled enemies are scaled here at spawn time instead of duplicating ~40
# .tres/.tscn files: an HP multiplier plus a flat starting Muscle grant per
# enemy. Muscle feeds the DMG_DEALT modifier, which every enemy attack applies
# to BOTH its real damage and its displayed intent (systemic fix of 2026-07-04),
# so one status raises every hit honestly and visibly. Keyed by the act-LOCAL
# tier (0-2 hallway by depth, 3 elite, 4 boss) that run.gd sets on `act_tier`.
# Tune the whole act from these two tables.
const ACT2_MUSCLE_STATUS := preload("res://statuses/muscle.tres")
const ACT2_HP_MULT := {0: 1.55, 1: 1.3, 2: 1.75, 3: 1.75, 4: 1.6}
const ACT2_MUSCLE_BASE := {0: 2, 1: 3, 2: 4, 3: 5, 4: 4}

# Act-local tier set by run.gd at room entry; -1 (debug launches without run.gd)
# falls back to the source battle's own tier label.
var act_tier: int = -1

# --- Combat background selection ------------------------------------------
# One background per (act, act-local tier) slot, keyed exactly like the scaling
# tables above. Act 1 arcs from open-air ruins toward a stormy sea-cliff for
# Leviathan; act 2 arcs from indoor archives toward a mistier variant of that
# same coastline for the Leviathan rematch (same boss both acts).
const BACKGROUND_ACT1 := {
    0: preload("res://assets/backgrounds/combat_bg_act1_t0_jungle.png"),
    1: preload("res://assets/backgrounds/combat_bg_act1_t1_desert.png"),
    2: preload("res://assets/backgrounds/combat_bg_act1_t2_throne_hall.png"),
    3: preload("res://assets/backgrounds/combat_bg_act1_elite_lava.png"),
    4: preload("res://assets/backgrounds/combat_bg_act1_boss_coastal_storm.png"),
}
const BACKGROUND_ACT2 := {
    0: preload("res://assets/backgrounds/combat_bg_act2_t0_arcane_library.png"),
    1: preload("res://assets/backgrounds/combat_bg_act2_t1_purple_library.png"),
    2: preload("res://assets/backgrounds/combat_bg_act2_t2_idol_shrine.png"),
    3: preload("res://assets/backgrounds/combat_bg_act2_elite_colosseum.png"),
    4: preload("res://assets/backgrounds/combat_bg_act2_boss_coastal_mist.png"),
}
const BACKGROUND_FALLBACK := preload("res://assets/backgrounds/20-2.jpg")

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
@export var music: AudioStream
@export var relics: RelicHandler
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var tooltip: CanvasLayer = $Tooltip

@onready var background: Sprite2D = $Background
@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler
@onready var enemy_handler: EnemyHandler = $EnemyHandler
@onready var player: Player = $Player
@onready var scout_panel: Panel = $ScoutPanel
@onready var scout_faces := [
    scout_panel.get_node("HBoxContainer/ScoutDice1"),
    scout_panel.get_node("HBoxContainer/ScoutDice2"),
    scout_panel.get_node("HBoxContainer/ScoutDice3"),
    scout_panel.get_node("HBoxContainer/ScoutDice4"),
    scout_panel.get_node("HBoxContainer/ScoutDice5"),
    scout_panel.get_node("HBoxContainer/ScoutDice6"),
]

@onready var dice_animation_check: TextureButton = $BattleUI/DiceAnimationControl/DiceAnimationOption/DiceAnimationCheck
@onready var warning_power_reset: Panel = $CanvasLayer/Tutorial/WarningPowerReset
@onready var warning_button: Button = $CanvasLayer/Tutorial/WarningPowerReset/WarningButton



func _ready() -> void:

    enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
    Events.enemy_turn_ended.connect(_on_enemy_turn_ended)

    Events.player_turn_ended.connect(player_handler.end_turn)
    Events.player_hand_discarded.connect(enemy_handler.start_turn)
    Events.player_died.connect(_on_player_died)
    Events.scout_effect.connect(_on_scout_effect)
    Events.stop_battle_music.connect(_on_stop_battle_music)
    Events.show_warning_message.connect(_on_show_warning_message)
    dice_animation_check.button_pressed = Global.testing_mode

    



func start_battle() -> void:
    get_tree().paused = false
    MusicPlayer.play(music, true)
    Events.stop_map_music.emit()
    background.texture = _select_background_texture()
    battle_ui.char_stats = char_stats
    player.stats = char_stats
    player_handler.relics = relics
    enemy_handler.setup_enemies(battle_stats)
    _apply_act2_scaling()
    enemy_handler.reset_enemy_actions()
    Global.fight_turn = 0
    Global.fight_dice_rolled = 0
    Global.dice_type = "blue"
    Global.hound_debuff_attack_done = false
    Global.gargantua_debuff_attack_done = false
    Global.ink_active = false
    # battle_started MUST fire before the START_OF_COMBAT relic cascade below: that cascade
    # synchronously calls player_handler.start_battle() -> start_turn() -> emits
    # player_turn_started, which recomputes each dice type's current_amount from its
    # "_bonus_amount_fight" fields (temporary dice granted mid-fight by cards like Cogwork).
    # dice.gd's _on_battle_started() is what zeroes those fields for the new fight - if it
    # ran AFTER player_turn_started (the old order), turn 1 of a new fight would still show
    # last fight's leftover temporary dice for exactly one turn before they got reset away.
    Events.battle_started.emit()
    relics.relics_activated.connect(_on_relics_activated)
    relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)


# Must run BETWEEN setup_enemies() (stats instances exist - set_enemy_stats
# duplicates the .tres via create_instance(), so mutating them here touches this
# fight only, never the shared resource) and reset_enemy_actions() (so the very
# first intent already displays the Muscle-boosted numbers).
func _apply_act2_scaling() -> void:
    if Global.current_act < 2 or not battle_stats:
        return
    var tier: int = act_tier if act_tier >= 0 else battle_stats.battle_tier
    var hp_mult: float = ACT2_HP_MULT.get(tier, 1.0)
    # setup_enemies() removes battle.tscn's editor-placed placeholder enemy (the
    # CrabEnemy under EnemyHandler) with queue_free(), which is DEFERRED - it's
    # still a child this frame, so it must be filtered out here or it inflates
    # the body count below and eats one point of the Muscle budget (a solo act-2
    # elite showed 4 stacks instead of 5 because of it).
    var enemies := enemy_handler.get_children().filter(
        func(child): return child is Enemy and not child.is_queued_for_deletion()
    )
    # The Muscle base is a per-FIGHT damage budget, not per-body: swarms already
    # multiply their damage output by body count, so each extra body shrinks the
    # per-enemy grant (solo gets the full base, a 4-pack gets base-3 each, min 1).
    var muscle_per_enemy: int = maxi(1, int(ACT2_MUSCLE_BASE.get(tier, 0)) - (enemies.size() - 1))
    for enemy in enemies:
        if enemy.stats == null:
            continue
        enemy.stats.max_health = roundi(enemy.stats.max_health * hp_mult)
        enemy.stats.health = enemy.stats.max_health
        var muscle: Status = ACT2_MUSCLE_STATUS.duplicate()
        muscle.stacks = muscle_per_enemy
        enemy.status_handler.add_status(muscle)


# Debug launches (act_tier still -1) and any unrecognized tier fall back to the
# original single background rather than guessing.
func _select_background_texture() -> Texture2D:
    if act_tier < 0:
        return BACKGROUND_FALLBACK
    var pool: Dictionary = BACKGROUND_ACT2 if Global.current_act >= 2 else BACKGROUND_ACT1
    return pool.get(act_tier, BACKGROUND_FALLBACK)


func _on_enemies_child_order_changed() -> void:
    if enemy_handler.get_child_count() == 0 and is_instance_valid(relics):
        relics.activate_relics_by_type(Relic.Type.END_OF_COMBAT)


func _on_enemy_turn_ended() -> void:
    player_handler.start_turn()
    enemy_handler.reset_enemy_actions()
    Events.hp_changed.emit()


func _on_player_died() -> void:
    Global.game_over_state = true
    # Permadeath: dying invalidates the run's save (the last checkpoint was the map
    # screen before this fight - keeping it would allow retrying the fight for free).
    SaveManager.delete_save()
    Events.stop_battle_music.emit()
    Events.battle_over_screen_requested.emit("Game Over!", BattleOverPanel.Type.LOSE)


func _on_relics_activated(type: Relic.Type) -> void:
    match type:
        Relic.Type.START_OF_COMBAT:
            player_handler.start_battle(char_stats)
            battle_ui.initialize_card_pile_ui()
        Relic.Type.END_OF_COMBAT:
            Global.blue_dice_bonus_amount = 0                
            Global.is_final_boss_fight = battle_stats.resource_path.contains("leviathan")
            Events.battle_over_screen_requested.emit("Victory!", BattleOverPanel.Type.WIN)
            Events.stop_battle_music.emit()


# Example dice face dictionary  (if not already defined elsewhere)
var dice_faces := {
    "blue": [
        load("res://assets/images/blue1.png"),
        load("res://assets/images/blue2.png"),
        load("res://assets/images/blue3.png"),
        load("res://assets/images/blue4.png"),
        load("res://assets/images/blue5.png"),
        load("res://assets/images/blue6.png"),
    ],
        "red": [
        load("res://assets/images/red1.png"),
        load("res://assets/images/red2.png"),
        load("res://assets/images/red3.png"),
        load("res://assets/images/red4.png"),
        load("res://assets/images/red5.png"),
        load("res://assets/images/red6.png"),
    ],
    "evil": [
        load("res://assets/images/evil0.png"),
        load("res://assets/images/evil6.png"),
        load("res://assets/images/evil6.png"),
        load("res://assets/images/evil6.png"),
    ],
    "giant": [
        load("res://assets/images/giant1.png"),
        load("res://assets/images/giant2.png"),
        load("res://assets/images/giant3.png"),
        load("res://assets/images/giant4.png"),
        load("res://assets/images/giant5.png"),
        load("res://assets/images/giant6.png"),
        load("res://assets/images/giant7.png"),
        load("res://assets/images/giant8.png"),
        load("res://assets/images/giant9.png"),
        load("res://assets/images/giant10.png"),
        load("res://assets/images/giant11.png"),
        load("res://assets/images/giant12.png"),
    ],
    "even": [
        load("res://assets/images/even2.png"),
        load("res://assets/images/even4.png"),
        load("res://assets/images/even6.png"),
        load("res://assets/images/even8.png"),
    ],
    "odd": [
        load("res://assets/images/odd1.png"),
        load("res://assets/images/odd3.png"),
        load("res://assets/images/odd5.png"),
        load("res://assets/images/odd7.png"),
    ],
    "magma": [
        load("res://assets/images/magma1.png"),
        load("res://assets/images/magma2.png"),
        load("res://assets/images/magma3.png"),
        load("res://assets/images/magma4.png"),
        load("res://assets/images/magma5.png"),
        load("res://assets/images/magma6.png"),
    ],
    "green": [
        load("res://assets/images/green1.png"),
        load("res://assets/images/green2.png"),
        load("res://assets/images/green3.png"),
    ],
    "mech": [
        load("res://assets/images/mech1.png"),
        load("res://assets/images/mech2.png"),
        load("res://assets/images/mech3.png"),
        load("res://assets/images/mech4.png"),
        load("res://assets/images/mech5.png"),
        load("res://assets/images/mech6.png"),
    ],
}



const SCOUT_DICE_SIZE := 50.0
const SCOUT_DICE_SEPARATION := 15.0
const SCOUT_PANEL_CENTER_X := 605.0  # (437 + 773) / 2 - the panel's original designed center, kept fixed so it doesn't drift across repeated resizes
const SCOUT_PANEL_MIN_WIDTH := 336.0  # original panel width - floor so 3-option Scouts (and fewer) look exactly as before
const SCOUT_PANEL_SIDE_PADDING := 60.0

# --- Scout animation (2026-07-11) --------------------------------------------
# The scout flow used to be fully instant: the panel snapped in with every face
# already visible, and a click snapped it all away while the next-roll slot just
# appeared. Now it's staged to read as one connected motion: glow motes rise from
# the active die into the panel as it unfolds, the roll options materialize one
# by one where the motes land, and the picked die flies down into the next-roll
# slot (trailing the die's accent color) while the panel folds back away.
const SCOUT_OPEN_TIME := 0.18
const SCOUT_FACE_REVEAL_START := 0.08   # delay before the first face starts materializing, lets the panel mostly land first
# Each option materializes with a couple of quick uncertain flickers before locking in -
# NOT a plain instant pop (tried, read as "an orb just hit a static die" rather than the die
# actually forming) and NOT the earlier long tease with a bigger "payoff" beat stacked onto
# the last option either (tried, read as dragging - most of the extra length was that one
# option's added suspense). This version treats every option identically and keeps the
# flicker itself short, so a 3-option Scout still lands around ~1s start-to-finish.
const SCOUT_FACE_REVEAL_STAGGER := 0.3
const SCOUT_FACE_TEASE_COUNT := 2       # quick flicker beats before an option commits
const SCOUT_FACE_TEASE_STEP := 0.055    # duration of one flicker half-step (up or down)
const SCOUT_FACE_TEASE_SCALE_LOW := 0.45
const SCOUT_FACE_TEASE_SCALE_HIGH := 0.82
const SCOUT_FACE_TEASE_ALPHA_LOW := 0.3
const SCOUT_FACE_TEASE_ALPHA_HIGH := 0.75
const SCOUT_FACE_REVEAL_TIME := 0.14    # the lock-in pop itself, snappy so it contrasts with the flicker
const SCOUT_OPEN_MOTE_FLIGHT := 0.22    # die -> panel rise time of one mote
const SCOUT_OPEN_MOTE_LEAD := 0.16      # launched this far before its face starts flickering, so it arrives right as the flicker begins
const SCOUT_CLOSE_TIME := 0.18
const SCOUT_CLOSE_DELAY := 0.08         # after a pick: the chosen die pops out first, THEN the panel folds
const SCOUT_PICK_PUNCH_SCALE := 1.22
const SCOUT_PICK_PUNCH_TIME := 0.11
const SCOUT_PICK_FLIGHT_TIME := 0.45
const SCOUT_PICK_ARC_LIFT := 60.0       # sideways bow of the pick's flight path
const SCOUT_TRAIL_SPACING := 0.16       # eased-t gap between trail motes (~6 per flight, evenly spaced along the path)
const SCOUT_PLUCK_SFX := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")  # same pluck as the power-orb landings

var _scout_tweens: Array[Tween] = []
var _scout_pick_in_progress := false
# Same soft-radial + additive-blend recipe as dice.gd's power orbs (those caches are instance
# state on the Dice control, so they're rebuilt here) - the scout motes must read as the same
# magic that charges the die, just pointed at the future instead of the Power number.
var _scout_glow_texture: GradientTexture2D
var _scout_glow_material: CanvasItemMaterial

# Widens the panel/dice row for Scout variants with more than 3 options (e.g. Scout 5) so the
# extra faces don't overflow the originally 3-option-sized layout. Centered on the panel's
# original position rather than its current one to avoid drift across repeated calls.
func _resize_scout_panel(visible_count: int) -> void:
    var hbox := scout_panel.get_node("HBoxContainer") as HBoxContainer
    var content_width: float = visible_count * SCOUT_DICE_SIZE + maxf(0, visible_count - 1) * SCOUT_DICE_SEPARATION
    hbox.offset_left = -content_width / 2.0
    hbox.offset_right = content_width / 2.0

    var panel_width: float = maxf(SCOUT_PANEL_MIN_WIDTH, content_width + SCOUT_PANEL_SIDE_PADDING)
    scout_panel.offset_left = SCOUT_PANEL_CENTER_X - panel_width / 2.0
    scout_panel.offset_right = SCOUT_PANEL_CENTER_X + panel_width / 2.0
    # Bottom-center pivot so the open/close scale reads as the panel unfolding up out of the
    # dice area below it (and folding back down into it) rather than ballooning in place.
    scout_panel.pivot_offset = Vector2(panel_width / 2.0, scout_panel.size.y)


func _on_scout_effect(amount: int) -> void:
    #audio_stream_player_2d.stream = load("res://sounds/fountainheal.wav")
    #audio_stream_player_2d.volume_db = 9
    #audio_stream_player_2d.play()
    var sfx_scout = preload("res://sfx/153724__carlos_vaquero__violoncello-snap-pizzicato-11.wav")
    SFXPlayer.play(sfx_scout)
    _kill_scout_tweens()
    _scout_pick_in_progress = false
    # Cartographer's Quill adds Global.scout_bonus_amount extra faces - clamped
    # to the panel's 6 hardcoded slots either way (bumped from 5 specifically so a
    # Scout 5 card still gets value out of the relic).
    var effective_amount: int = amount + Global.scout_bonus_amount
    var visible_count: int = min(effective_amount, scout_faces.size())
    _resize_scout_panel(visible_count)

    var faces = dice_faces.get(Global.dice_type, [])
    if faces.is_empty():
        push_error("No faces found for dice type: %s" % Global.dice_type)
        return

    var selected_faces: Array = []
    if not Global.tutorial_forced_scout_faces.is_empty():
        for i in range(visible_count):
            var forced_tex: Texture2D = null
            if i < Global.tutorial_forced_scout_faces.size():
                forced_tex = _find_dice_face_texture(faces, Global.tutorial_forced_scout_faces[i])
            selected_faces.append(forced_tex if forced_tex else faces[randi() % faces.size()])
        Global.tutorial_forced_scout_faces = []
    else:
        for i in range(visible_count):
            selected_faces.append(faces[randi() % faces.size()])

    # The panel unfolds up out of the dice area instead of snapping in (pivot set
    # bottom-center by _resize_scout_panel above).
    scout_panel.show()
    scout_panel.scale = Vector2(0.7, 0.7)
    scout_panel.modulate.a = 0.0
    var open_tween := create_tween()
    open_tween.tween_property(scout_panel, "modulate:a", 1.0, SCOUT_OPEN_TIME * 0.6)
    open_tween.parallel().tween_property(scout_panel, "scale", Vector2.ONE, SCOUT_OPEN_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _scout_tweens.append(open_tween)

    _spawn_scout_open_motes(visible_count)

    for i in range(scout_faces.size()):
        var face = scout_faces[i]
        if i < selected_faces.size():
            face.texture = selected_faces[i]
            face.show()

            # Disconnect old connections to avoid duplicates
            if face.is_connected("gui_input", _on_scout_dice_clicked):
                face.disconnect("gui_input", _on_scout_dice_clicked)

            # Connect click signal with the correct face
            face.gui_input.connect(_on_scout_dice_clicked.bind(face))

            # Revealed one at a time where its mote lands: a couple of quick uncertain
            # flickers (scale/alpha pulsing, like the option is still catching) before it
            # commits with an overbright pop. Every option gets the exact same treatment -
            # no extra beats on any one of them. Not clickable until fully committed - an
            # invisible/mid-flicker TextureRect still receives gui_input, so a blind click
            # could otherwise pick an option the player never got to see land.
            face.pivot_offset = face.size / 2.0
            face.scale = Vector2.ZERO
            face.modulate = Color(1, 1, 1, 0)
            face.mouse_filter = Control.MOUSE_FILTER_IGNORE

            var reveal := create_tween()
            reveal.tween_interval(SCOUT_FACE_REVEAL_START + SCOUT_FACE_REVEAL_STAGGER * i)

            for t in range(SCOUT_FACE_TEASE_COUNT):
                reveal.tween_property(face, "scale", Vector2.ONE * SCOUT_FACE_TEASE_SCALE_HIGH, SCOUT_FACE_TEASE_STEP) \
                    .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
                reveal.parallel().tween_property(face, "modulate:a", SCOUT_FACE_TEASE_ALPHA_HIGH, SCOUT_FACE_TEASE_STEP)
                reveal.tween_property(face, "scale", Vector2.ONE * SCOUT_FACE_TEASE_SCALE_LOW, SCOUT_FACE_TEASE_STEP) \
                    .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
                reveal.parallel().tween_property(face, "modulate:a", SCOUT_FACE_TEASE_ALPHA_LOW, SCOUT_FACE_TEASE_STEP)

            reveal.tween_callback(_play_scout_reveal_sfx.bind(i))
            reveal.tween_property(face, "modulate", Color(1.9, 1.9, 1.9, 1.0), SCOUT_FACE_TEASE_STEP * 0.6) \
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
            reveal.parallel().tween_property(face, "scale", Vector2.ONE, SCOUT_FACE_REVEAL_TIME) \
                .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            reveal.tween_property(face, "modulate", Color.WHITE, SCOUT_FACE_REVEAL_TIME * 1.6)
            reveal.tween_callback(_make_scout_face_clickable.bind(face))
            _scout_tweens.append(reveal)
        else:
            face.hide()

# Finds the face texture whose filename encodes the given value (same convention
# _on_scout_dice_clicked already parses picked faces with, e.g. "blue3.png" -> 3) -
# used by the tutorial to force specific Scout faces instead of a random pick.
func _find_dice_face_texture(faces: Array, value: int) -> Texture2D:
    var regex := RegEx.new()
    regex.compile(r"(\d+)\.png$")
    for tex: Texture2D in faces:
        var result := regex.search(tex.resource_path)
        if result and int(result.get_string(1)) == value:
            return tex
    return null


func _on_scout_dice_clicked(event: InputEvent, face: TextureRect) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if _scout_pick_in_progress:
            return
        var tex_path = face.texture.resource_path

        # Extract the number from the filename (e.g., blue3.png → 3)
        var regex := RegEx.new()
        regex.compile(r"(\d+)\.png$")
        var result := regex.search(tex_path)
        if result:
            _scout_pick_in_progress = true
            # State first, visuals after (same principle as the Power number updating
            # instantly while the orbs fly): the guarantee is set NOW, the flight below is
            # purely the story of it traveling to the next-roll slot. next_roll_determined
            # is emitted on touchdown instead of here - see _land_scout_pick.
            Global.next_guaranteed_roll = int(result.get_string(1))
            print("Selected guaranteed roll:", Global.next_guaranteed_roll)
            audio_stream_player_2d.stream = load("res://sounds/fountainheal.wav")
            audio_stream_player_2d.volume_db = 9
            audio_stream_player_2d.play()
            _fly_scout_pick_to_next_roll(face)
            _close_scout_panel(face)
        else:
            push_error("Failed to extract number from: %s" % tex_path)


func _kill_scout_tweens() -> void:
    for t in _scout_tweens:
        if t and t.is_valid():
            t.kill()
    _scout_tweens.clear()


func _make_scout_face_clickable(face: TextureRect) -> void:
    face.mouse_filter = Control.MOUSE_FILTER_STOP


# Rising arpeggio, one pluck per revealed face - same sample as the power-orb landings so
# scouting sounds like the same magic, just climbing instead of scattering.
func _play_scout_reveal_sfx(index: int) -> void:
    SFXPlayer.play(SCOUT_PLUCK_SFX, false, 0.85 + 0.1 * index, -3.0)


# One small glow mote per revealed face, rising from the active die up into the panel - "the
# die projects its futures". Each is timed to arrive just as its face pops in, so the reveal
# reads as caused by the arriving spark. Targets are computed arithmetically (same formula as
# _resize_scout_panel) rather than read from the HBox children: container layout only settles
# at the end of the frame, so freshly-resized face positions would still be stale here.
func _spawn_scout_open_motes(visible_count: int) -> void:
    var die := get_node_or_null("ActiveDice/Panel/DiceDisplay") as Control
    if die == null:
        return
    var parent_layer: Node = get_tree().get_first_node_in_group("ui_layer")
    if parent_layer == null:
        parent_layer = self
    var start := die.get_global_rect().get_center()
    var accent := DicePalette.accent(Global.dice_type)
    var face_center_y := scout_panel.offset_top + 77.0  # HBox offset_top (52) + half a face (25)

    for i in range(visible_count):
        var target := Vector2(
            SCOUT_PANEL_CENTER_X + (i - (visible_count - 1) / 2.0) * (SCOUT_DICE_SIZE + SCOUT_DICE_SEPARATION),
            face_center_y)

        var mote := TextureRect.new()
        mote.texture = _get_scout_glow_texture()
        mote.material = _get_scout_glow_material()
        mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        var size := randf_range(9.0, 13.0)
        mote.size = Vector2(size, size)
        mote.pivot_offset = mote.size / 2.0
        mote.modulate = accent * 1.6
        mote.modulate.a = 0.0
        mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mote.z_index = 149
        parent_layer.add_child(mote)
        mote.global_position = start + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)) - mote.size / 2.0
        mote.scale = Vector2(0.6, 0.6)

        var launch_delay: float = maxf(0.0, SCOUT_FACE_REVEAL_START + SCOUT_FACE_REVEAL_STAGGER * i - SCOUT_OPEN_MOTE_LEAD)
        var mt := create_tween()
        mt.tween_interval(launch_delay)
        mt.tween_property(mote, "modulate:a", 1.0, 0.07)
        mt.parallel().tween_property(mote, "global_position", target - mote.size / 2.0, SCOUT_OPEN_MOTE_FLIGHT) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        mt.parallel().tween_property(mote, "scale", Vector2.ONE, SCOUT_OPEN_MOTE_FLIGHT)
        mt.tween_property(mote, "modulate:a", 0.0, 0.1)
        mt.parallel().tween_property(mote, "scale", Vector2(0.3, 0.3), 0.1)
        mt.tween_callback(mote.queue_free)
        _scout_tweens.append(mt)


# Folds the panel away. With a picked face: that face goes instantly invisible (the flying
# clone replaces it), its siblings shrink out, and the panel itself waits a beat so the pick
# visibly pops OUT of the panel before the panel follows. Without one (Exit button): same
# close, just immediate and with nothing excluded.
func _close_scout_panel(picked_face: TextureRect = null) -> void:
    _kill_scout_tweens()
    if picked_face:
        # Alpha instead of hide() - hiding would re-flow the HBoxContainer and shift the
        # remaining faces sideways mid-close.
        picked_face.modulate.a = 0.0
    var fade_index := 0
    for face in scout_faces:
        if face == picked_face or not face.visible:
            continue
        face.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no late picks while fading out
        var t := create_tween()
        t.tween_interval(0.02 * fade_index)
        t.tween_property(face, "modulate:a", 0.0, 0.1)
        t.parallel().tween_property(face, "scale", Vector2(0.6, 0.6), 0.1) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        _scout_tweens.append(t)
        fade_index += 1

    var close := create_tween()
    if picked_face:
        close.tween_interval(SCOUT_CLOSE_DELAY)
    close.tween_property(scout_panel, "scale", Vector2(0.8, 0.8), SCOUT_CLOSE_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    close.parallel().tween_property(scout_panel, "modulate:a", 0.0, SCOUT_CLOSE_TIME)
    close.tween_callback(_finish_scout_close)
    _scout_tweens.append(close)


func _finish_scout_close() -> void:
    scout_panel.hide()
    scout_panel.scale = Vector2.ONE
    scout_panel.modulate.a = 1.0


# The picked die pops out of the panel and is pulled down into the next-roll slot at the
# bottom right of the central die, trailing glow motes in the die's accent color - same
# flight language as the refuel-return icons (punch, then TRANS_QUAD/EASE_IN "pulled" arc).
func _fly_scout_pick_to_next_roll(face: TextureRect) -> void:
    var slot := get_node_or_null("ActiveDice/NextRollPanel") as Control
    if slot == null:
        # Nothing to fly to (debug launches without the dice scene) - reveal instantly.
        Events.next_roll_determined.emit()
        return
    var parent_layer: Node = get_tree().get_first_node_in_group("ui_layer")
    if parent_layer == null:
        parent_layer = self

    var start := face.get_global_rect().get_center()
    var target := slot.get_global_rect().get_center()

    var flyer := TextureRect.new()
    flyer.texture = face.texture
    flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    flyer.size = face.size
    flyer.pivot_offset = flyer.size / 2.0
    flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flyer.z_index = 150  # same layer/z convention as the refuel and All In flourish icons
    parent_layer.add_child(flyer)
    flyer.global_position = start - flyer.size / 2.0

    # Deterministic sideways bow (one clean hero arc, not the orbs' random wobble - a single
    # die squiggling around reads as drunk, not elegant).
    var dir := (target - start).normalized()
    var perp := Vector2(-dir.y, dir.x)
    var control := start.lerp(target, 0.45) - perp * SCOUT_PICK_ARC_LIFT

    var trail_state := {"last_t": 0.0}
    var accent := DicePalette.accent(Global.dice_type)

    var flight := create_tween()
    # 1. "Chosen!" punch before departing.
    flight.tween_property(flyer, "scale", Vector2.ONE * SCOUT_PICK_PUNCH_SCALE, SCOUT_PICK_PUNCH_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    # 2. Accelerating pull down into the next-roll slot, leaving a trail. The eased t drives
    # the trail spacing too, so motes end up evenly spaced along the PATH, not in time.
    flight.tween_method(
            _scout_pick_bezier_step.bind(flyer, start, control, target, trail_state, accent, parent_layer),
            0.0, 1.0, SCOUT_PICK_FLIGHT_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    flight.parallel().tween_property(flyer, "scale", Vector2.ONE, SCOUT_PICK_FLIGHT_TIME)
    # 3. Handoff: the flyer vanishes in the same instant the real slot pops in (dice.gd's
    # _on_next_roll_determined plays the arrival punch), so the die reads as BECOMING the
    # next-roll display rather than disappearing next to it.
    flight.tween_callback(_land_scout_pick)
    flight.tween_callback(flyer.queue_free)


func _scout_pick_bezier_step(t: float, flyer: TextureRect, p0: Vector2, p1: Vector2, p2: Vector2, trail_state: Dictionary, accent: Color, parent_layer: Node) -> void:
    var pos := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
    flyer.global_position = pos - flyer.size / 2.0
    if t - trail_state["last_t"] >= SCOUT_TRAIL_SPACING:
        trail_state["last_t"] = t
        _spawn_scout_trail_mote(pos, accent, parent_layer)


func _spawn_scout_trail_mote(pos: Vector2, accent: Color, parent_layer: Node) -> void:
    var mote := TextureRect.new()
    mote.texture = _get_scout_glow_texture()
    mote.material = _get_scout_glow_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var size := randf_range(10.0, 16.0)
    mote.size = Vector2(size, size)
    mote.pivot_offset = mote.size / 2.0
    mote.modulate = accent * 1.5
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.z_index = 149  # just under the flying die
    parent_layer.add_child(mote)
    mote.global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)) - mote.size / 2.0
    var fade := create_tween()
    fade.tween_property(mote, "modulate:a", 0.0, 0.32) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fade.parallel().tween_property(mote, "scale", Vector2(0.25, 0.25), 0.32) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fade.tween_callback(mote.queue_free)


func _land_scout_pick() -> void:
    # A roll (or an active-dice switch) during the flight consumes/clears the guarantee -
    # dice.gd resets it to -1 and hides the slot. In that case there's nothing left to
    # deliver, so don't pop an empty/stale panel.
    if Global.next_guaranteed_roll == -1:
        return
    Events.next_roll_determined.emit()
    SFXPlayer.play(SCOUT_PLUCK_SFX, false, 0.7, -2.0)


func _get_scout_glow_texture() -> GradientTexture2D:
    if _scout_glow_texture:
        return _scout_glow_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 32
    tex.height = 32
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    _scout_glow_texture = tex
    return _scout_glow_texture


func _get_scout_glow_material() -> CanvasItemMaterial:
    if _scout_glow_material:
        return _scout_glow_material
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _scout_glow_material = mat
    return _scout_glow_material

# Fixed screen-space anchors (design resolution 1280x720) instead of mouse
# position: mouse-anchored placement was getting clipped by the screen edge.
# Sitting just above their respective buttons; the discard one can overlap
# EndTurnButton, that's fine since it disappears on mouse exit anyway.
const DRAW_PILE_TOOLTIP_POS := Vector2(43, 510)
const DISCARD_PILE_TOOLTIP_POS := Vector2(1056, 510)

func _show_pile_tooltip(title: String, text: String, pos: Vector2) -> void:
    tooltip.visible = true
    var tooltip_panel = tooltip.get_node("Tooltip")
    tooltip_panel.tooltip_title.text = "[center][color=gold][b]%s[/b][/color][/center]" % title
    tooltip_panel.tooltip_label.text = "[center]%s[/center]" % text
    tooltip_panel.show_tooltip(pos)

func _hide_pile_tooltip() -> void:
    var tooltip_panel = tooltip.get_node("Tooltip")
    tooltip_panel.hide_tooltip()
    tooltip.visible = false

func _on_draw_pile_button_mouse_entered() -> void:
    _show_pile_tooltip("Draw Pile", "The cards left to draw. Refills from your Discard Pile once empty.", DRAW_PILE_TOOLTIP_POS)

func _on_draw_pile_button_mouse_exited() -> void:
    _hide_pile_tooltip()

func _on_discard_pile_button_mouse_entered() -> void:
    _show_pile_tooltip("Discard Pile", "Cards you've played. Shuffles back into your Draw Pile once it runs out.", DISCARD_PILE_TOOLTIP_POS)

func _on_discard_pile_button_mouse_exited() -> void:
    _hide_pile_tooltip()


func _on_stop_battle_music() -> void:
    MusicPlayer.stop()





func _on_show_warning_message() -> void:
    warning_power_reset.show()

func _on_warning_button_pressed() -> void:
    warning_power_reset.hide()


func _on_dice_animation_check_toggled(toggled_on: bool) -> void:
    Global.testing_mode =  toggled_on


func _on_exit_button_pressed() -> void:
    _close_scout_panel()
