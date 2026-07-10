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

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
@export var music: AudioStream
@export var relics: RelicHandler
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var tooltip: CanvasLayer = $Tooltip

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

@onready var tutorial_dimmer: ColorRect = $CanvasLayer/TutorialDimmer

@onready var tutorial_1: Panel = $CanvasLayer/Tutorial/Tutorial1
@onready var tutorial_1_button: Button = $CanvasLayer/Tutorial/Tutorial1/Tutorial1Button
@onready var tutorial_2: Panel = $CanvasLayer/Tutorial/Tutorial2

#
#@onready var tutorial_1: Panel = $Tutorial/Tutorial1
#@onready var tutorial_1_button: Button = $Tutorial/Tutorial1/Tutorial1Button

@onready var tutorial_3: Panel = $CanvasLayer/Tutorial/Tutorial3
@onready var tutorial_4: Panel = $CanvasLayer/Tutorial/Tutorial4
@onready var tutorial_5: Panel = $CanvasLayer/Tutorial/Tutorial5
@onready var tutorial_6: Panel = $CanvasLayer/Tutorial/Tutorial6
@onready var tutorial_7: Panel = $CanvasLayer/Tutorial/Tutorial7
@onready var tutorial_8: Panel = $CanvasLayer/Tutorial/Tutorial8
@onready var tutorial_9: Panel = $CanvasLayer/Tutorial/Tutorial9
@onready var tutorial_10: Panel = $CanvasLayer/Tutorial/Tutorial10
@onready var tutorial_11: Panel = $CanvasLayer/Tutorial/Tutorial11
@onready var tutorial_12: Panel = $CanvasLayer/Tutorial/Tutorial12
@onready var tutorial_13: Panel = $CanvasLayer/Tutorial/Tutorial13
@onready var tutorial_14: Panel = $CanvasLayer/Tutorial/Tutorial14
@onready var tutorial_15: Panel = $CanvasLayer/Tutorial/Tutorial15
@onready var skip_tutorial_button: Button = $CanvasLayer/Tutorial/SkipTutorialButton


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
    Events.tutorial_step_requested.connect(_on_tutorial_step_requested)
    Events.show_warning_message.connect(_on_show_warning_message)
    if Global.tutorial_on:
        tutorial_1.show()
        tutorial_dimmer.show()
        skip_tutorial_button.show()
    dice_animation_check.button_pressed = Global.testing_mode

    



func start_battle() -> void:
    get_tree().paused = false
    MusicPlayer.play(music, true)
    Events.stop_map_music.emit()
    battle_ui.char_stats = char_stats
    player.stats = char_stats
    player_handler.relics = relics
    enemy_handler.setup_enemies(battle_stats)
    _apply_act2_scaling()
    enemy_handler.reset_enemy_actions()
    relics.relics_activated.connect(_on_relics_activated)
    relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)
    Global.fight_turn = 0
    Global.fight_dice_rolled = 0
    Global.dice_type = "blue"
    Global.hound_debuff_attack_done = false
    Global.gargantua_debuff_attack_done = false
    Global.ink_active = false
    Events.battle_started.emit()


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


func _on_scout_effect(amount: int) -> void:
    #audio_stream_player_2d.stream = load("res://sounds/fountainheal.wav")
    #audio_stream_player_2d.volume_db = 9
    #audio_stream_player_2d.play()
    var sfx_scout = preload("res://sfx/153724__carlos_vaquero__violoncello-snap-pizzicato-11.wav")
    SFXPlayer.play(sfx_scout)
    scout_panel.show()
    # Cartographer's Quill adds Global.scout_bonus_amount extra faces - clamped
    # to the panel's 6 hardcoded slots either way (bumped from 5 specifically so a
    # Scout 5 card still gets value out of the relic).
    var effective_amount: int = amount + Global.scout_bonus_amount
    _resize_scout_panel(min(effective_amount, scout_faces.size()))

    var faces = dice_faces.get(Global.dice_type, [])
    if faces.is_empty():
        push_error("No faces found for dice type: %s" % Global.dice_type)
        return

    var selected_faces: Array = []
    for i in range(min(effective_amount, scout_faces.size())):
        selected_faces.append(faces[randi() % faces.size()])

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
        else:
            face.hide()

func _on_scout_dice_clicked(event: InputEvent, face: TextureRect) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var tex_path = face.texture.resource_path

        # Extract the number from the filename (e.g., blue3.png → 3)
        var regex := RegEx.new()
        regex.compile(r"(\d+)\.png$")
        var result := regex.search(tex_path)
        if result:
            Global.next_guaranteed_roll = int(result.get_string(1))
            print("Selected guaranteed roll:", Global.next_guaranteed_roll)
            Events.next_roll_determined.emit()
            scout_panel.hide()
            audio_stream_player_2d.stream = load("res://sounds/fountainheal.wav")
            audio_stream_player_2d.volume_db = 9
            audio_stream_player_2d.play()
        else:
            push_error("Failed to extract number from: %s" % tex_path)

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





func _on_tutorial_1_button_pressed() -> void:
    tutorial_dimmer.hide()
    tutorial_1.hide()
    tutorial_2.show()
    Global.tutorial_forced_roll = 6

func _on_tutorial_step_requested(step) -> void:
    if Global.tutorial_on:
        if step == 3:
            tutorial_2.hide()
            tutorial_3.show()
            Global.tutorial_block = true
        if step == 5:
            tutorial_4.hide()
            tutorial_5.show()
        if step == 6:
            tutorial_6.hide()
            tutorial_7.show()
        if step == 8: 
            tutorial_7.hide()
            tutorial_8.show()
            Global.tutorial_red_dice = true
        if step == 9:
            tutorial_8.hide()
            tutorial_9.show()
            Global.tutorial_charging_card = true
        if step == 10:
            tutorial_9.hide()
            tutorial_10.show()
            Global.tutorial_forced_roll = 5
            Global.tutorial_red_attack = true
        if step == 11:
            tutorial_10.hide()
            tutorial_11.show()
            Global.tutorial_end_turn = true
            Global.tutorial_second_turn = true
        if step == 12:
            tutorial_11.hide()
            tutorial_12.show()
            Global.tutorial_blue_dice = true
        if step == 13:
            tutorial_12.hide()
            tutorial_13.show()
            Global.tutorial_forced_roll = 2
        if step == 14:
            tutorial_13.hide()
            tutorial_14.show()
            Global.tutorial_recombobulate = true
        if step == 15:
            tutorial_14.hide()
            tutorial_15.show()
            Global.tutorial_on = false


        


func _on_tutorial_3_button_pressed() -> void:
    tutorial_3.hide()
    tutorial_4.show()


func _on_tutorial_5_button_pressed() -> void:
    tutorial_5.hide()
    tutorial_6.show()
    Global.tutorial_forced_roll = 3
    Global.tutorial_low_blow = true


func _on_tutorial_15_button_pressed() -> void:
    tutorial_15.hide()
    skip_tutorial_button.hide()
    Global.tutorial_on = false

func _on_show_warning_message() -> void:
    warning_power_reset.show()

func _on_warning_button_pressed() -> void:
    warning_power_reset.hide()
    


func _on_dice_animation_check_toggled(toggled_on: bool) -> void:
    Global.testing_mode =  toggled_on


func _on_skip_tutorial_button_pressed() -> void:
    end_tutorial()
    
func end_tutorial() -> void:
    for child in $CanvasLayer/Tutorial.get_children():
        child.hide()
    tutorial_dimmer.hide()
    Global.tutorial_on = false
    Global.tutorial_block = false 
    Global.tutorial_fight = false
    # manquants :
    Global.tutorial_forced_roll = 0
    Global.tutorial_red_dice = false
    Global.tutorial_charging_card = false
    Global.tutorial_red_attack = false
    Global.tutorial_end_turn = false
    Global.tutorial_second_turn = false
    Global.tutorial_blue_dice = false
    Global.tutorial_low_blow = false
    Global.tutorial_recombobulate = false
    
    
func _any_tutorial_panel_visible() -> bool:
    for child in $CanvasLayer/Tutorial.get_children():
        if child.visible:
            return true
    return false


func _on_exit_button_pressed() -> void:
    scout_panel.hide()
