class_name DiceInterface
extends Control

signal active_dice_changed(active_dice)

const TooltipScene = preload("res://scenes/ui/dice_tooltip.tscn")
# The dice tooltip sits centred just ABOVE the slot row, bottom-anchored so it grows upward
# instead of down into the row (its height tracks its text: 88px for a plain "Faces: 1-6",
# up to 120px once an infusion appends its effect line). The floor keeps the tallest case
# 2px clear of the top bar, which ends at y=80; at that extreme the bottom lands exactly on
# the row's top edge rather than crossing it.
const DICE_TOOLTIP_BOTTOM := 196.0   # row top is 202
const DICE_TOOLTIP_CENTER_X := 594.0 # centre of the slot row (514..674)
const DICE_TOOLTIP_MIN_TOP := 56.0
const DICE_TYPE_TO_NODE = {
    "blue": "dice_1", "red": "dice_2", "evil": "dice_3",
    "giant": "dice_4", "magma": "dice_5", "even": "dice_6",
    "odd": "dice_7", "green": "dice_8", "mech": "dice_9"
}
const DICE_TYPE_TO_AMOUNT = {
    "blue": "blue_dice_current_amount", "red": "red_dice_current_amount", "evil": "evil_dice_current_amount",
    "giant": "giant_dice_current_amount", "magma": "magma_dice_current_amount", "even": "even_dice_current_amount",
    "odd": "odd_dice_current_amount", "green": "green_dice_current_amount", "mech": "mech_dice_current_amount"
}
# Selected-slot highlight color comes from DicePalette (same source as the rolled die /
# Power number color elsewhere in the HUD).

# ── Charge delivery (Events.dice_charged) ──────────────────────────────────────────────
# When something charges dice, the gained dice physically ARRIVE: one die icon per charge
# pops out of the played card (or the active die, for relic/status/trigger charges), arcs
# to the charged type's slot trailing motes in that type's accent, and lands with a flash
# + rising-pitch clink per die. Counts/labels update immediately at emit (house convention,
# same as the Power number) - the flight is confirmation, never the source of truth.
const CHARGE_BIRTH_TIME := 0.16     # pop-out-of-the-card beat
const CHARGE_FLIGHT_TIME := 0.46    # per-die arc, launch -> slot (faster = harder landing)
const CHARGE_STAGGER := 0.16        # launch spacing inside one volley ("bam bam bam")
const CHARGE_MAX_ICONS := 6         # visual cap - the labels already told the full truth
const CHARGE_ICON_SIZE := 54.0
const CHARGE_TRAIL_INTERVAL_MS := 16  # real-time mote throttle along the arc
# Arrival is THE beat, so it gets the full impact package the thrown-dice bash uses
# (dice.gd): flare + shock ring + a BURST of motes + overbright ghost + hit-stop. Mass is
# what the eye reads, not shape - a lone streak reads as nothing next to a spray of motes
# (the slash-vs-particles lesson), hence the burst count rather than a bigger single flash.
# Dialled back once the big die got its universal shockwave (dice.gd::_spawn_charge_shockwave,
# 2026-08-14): the slot side no longer has to carry the whole event on its own, so it can go
# back to doing its actual job - saying precisely WHERE the dice landed - instead of shouting.
const CHARGE_ARRIVAL_MOTES := 6         # per die; the final die of a volley gets ~1.8x
const CHARGE_GHOST_BRIGHTNESS := 2.4    # >= ~1.9 or it is invisible at speed (documented)
const CHARGE_HIT_STOP_SCALE := 0.05     # how HARD the freeze is (the visibility factor)
const CHARGE_HIT_STOP_COOLDOWN_MS := 350  # keeps chained volleys from stuttering
const CHARGE_LAUNCH_SOUND := preload("res://chargedicesound.mp3")
const CHARGE_ARRIVE_SOUND := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const CHARGE_FINAL_SOUND := preload("res://sounds/dicerollsound3.mp3")
# Safety net only - the projectile normally borrows the slot's own texture, so the die
# that flies in IS the die sitting in the slot. (green is a d3: never assume a 6 face.)
const CHARGE_FALLBACK_FACE := {
    "blue": "blue6", "red": "red6", "evil": "evil6", "giant": "giant12", "magma": "magma6",
    "even": "even8", "odd": "odd7", "green": "green3", "mech": "mech6",
}

@onready var control: DiceInterface = $"."
@onready var dice_1: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice1
@onready var dice_2: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice2
@onready var dice_1_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice1/Dice1Label
@onready var dice_2_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice2/Dice2Label
@onready var dice_3: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice3
@onready var dice_3_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice3/Dice3Texture
@onready var dice_3_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice3/Dice3Label
@onready var h_box_container: HBoxContainer = $DicePanel/MarginContainer/HBoxContainer
@onready var dice_1_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice1/Dice1Texture
@onready var dice_2_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice2/Dice2Texture
@onready var dice_4_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice4/Dice4Texture
@onready var dice_5_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice5/Dice5Texture
@onready var dice_4: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice4
@onready var dice_5: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice5
@onready var dice_4_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice4/Dice4Label
@onready var dice_panel: Panel = $DicePanel
@onready var dice_5_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice5/Dice5Label
@onready var dice_6: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice6
@onready var dice_6_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice6/Dice6Texture
@onready var dice_6_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice6/Dice6Label
@onready var dice_7: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice7
@onready var dice_7_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice7/Dice7Texture
@onready var dice_7_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice7/Dice7Label
@onready var animation_player: AnimationPlayer = $DicePanel/AnimationPlayer
@onready var dice_8: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice8
@onready var dice_8_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice8/Dice8Texture
@onready var dice_8_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice8/Dice8Label
@onready var dice_9: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice9
@onready var dice_9_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice9/Dice9Texture
@onready var dice_9_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice9/Dice9Label


var tooltip_instance: CanvasLayer
# Looping pulse tweens on slots that still have dice while the active type is spent AND no
# Power is banked. _nudge_nodes tracks which slots are currently pulsing so a refresh whose
# nudge-set is unchanged leaves the running tweens alone (no restart-mid-breath).
var _nudge_tweens: Array[Tween] = []
var _nudge_nodes: Array = []
# Charge delivery state. _materializing_slots holds slots whose die type was just gained for
# the first time this fight: they keep their layout space but stay at alpha 0 until the first
# delivered die ARRIVES (the materialization IS the arrival), so the styling loop in
# update_selected_highlight must skip them or it would stomp the held alpha.
var _materializing_slots: Array = []
var _panel_kick_tween: Tween    # tracked: overlapping arrivals restart the kick, never stack
var _last_hit_stop_ms := -99999
var _charge_sound_frame := -1   # coalesce the launch sound across same-frame charge events
var _charge_volley_frame := -1  # sequence same-frame volleys (multi-type charges) instead of
var _charge_volley_delay := 0.0 # flying them on top of each other
var _last_card_play_frame := -1 # "did a card play THIS frame" - picks the flight origin
# Exactly-once bookkeeping for Events.dice_charge_delivered. The arrival callback and the
# failsafe timer both race to fire it; the token is erased by whichever wins.
var _charge_volley_seq := 0
var _pending_charge_volleys := {}



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # Draw the slot row ABOVE the big die's aura/emanation. Both sat at z 0 and tree order
    # put the die's layers on top, so the charge pulse washed these count labels out as it
    # expanded - which is what capped how bright that pulse was allowed to get. Set here
    # rather than on the battle.tscn instance so it also holds in every harness that builds
    # this row by hand. Safe: the flying charge-delivery icons live on the ui_layer
    # CanvasLayer at z 150 and the ROLL button is z 10, so both still draw over this.
    z_index = 5
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
    # Connect event listener for dice rolls
    Events.dice_rolled.connect(_on_dice_rolled)
    Events.dice_amount_changed.connect(_on_dice_amount_changed)
    Events.player_turn_started.connect(_on_player_turn_started)
    Events.player_turn_ended.connect(_on_player_turn_ended)
    Events.dice_bought.connect(_on_dice_bought)
    Events.resize_dice_interface.connect(_on_resize_dice_interface)
    Events.dice_charged.connect(_on_dice_charged)
    # Only used to decide the delivery's launch point (card release vs active die) - the
    # card's apply_effects (which emits dice_charged) runs synchronously inside play(), so
    # a same-frame check is exact.
    Events.card_played.connect(_on_card_played_for_charge)
    initialize_dices()
    _resize_panel_for_dice_inventory()
    Events.temporary_dice_added.connect(_on_temporary_dice_added)
    Events.active_dice_changed.connect(update_selected_highlight)
    # Fires after every roll AND after a card spends your Power to 0 (end of the reset
    # handler, past the red path's await) - the moment the "you're out, switch" nudge
    # should start or stop. Idempotent, so re-firing without a state change is a no-op.
    Events.hover_playable_cards.connect(_on_hover_playable_cards)
    await get_tree().process_frame
    update_selected_highlight(Global.dice_type)




# Called when a dice is rolled
func _on_dice_rolled(dice_type: String, roll_value: int):
    # A Ricochet reroll re-rolls the die already spent on the first result, so it must not
    # consume a second one. Skipping the per-type branch skips its label refresh too, which is
    # correct (the count didn't move) - but the highlight refresh at the tail of this function
    # still has to run, since the reroll DID change Global.roll_value and that drives the
    # "you still have dice on another slot" nudge.
    if Global.ricochet_reroll_active:
        update_selected_highlight()
        return
    if Global.dice_type == "blue":  # Reduce only if it's the blue die
        if Global.blue_dice_current_amount > 0:  
            Global.blue_dice_current_amount -= 1
            dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    elif Global.dice_type == "red":  # Reduce only if it's the blue die
        if Global.red_dice_current_amount > 0:  
            Global.red_dice_current_amount -= 1
            dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    elif Global.dice_type == "evil":  # Reduce only if it's the blue die
        if Global.evil_dice_current_amount > 0:  
            Global.evil_dice_current_amount -= 1
            dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    elif Global.dice_type == "giant":  # Reduce only if it's the blue die
        if Global.giant_dice_current_amount > 0:  
            Global.giant_dice_current_amount -= 1
            dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    elif Global.dice_type == "magma":  # Reduce only if it's the blue die
        if Global.magma_dice_current_amount > 0:  
            Global.magma_dice_current_amount -= 1
            dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    elif Global.dice_type == "even":  # Reduce only if it's the blue die
        if Global.even_dice_current_amount > 0:  
            Global.even_dice_current_amount -= 1
            dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    elif Global.dice_type == "odd":  # Reduce only if it's the blue die
        if Global.odd_dice_current_amount > 0:  
            Global.odd_dice_current_amount -= 1
            dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    elif Global.dice_type == "green":  # Reduce only if it's the blue die
        if Global.green_dice_current_amount > 0:  
            Global.green_dice_current_amount -= 1
            dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    elif Global.dice_type == "mech":  # Reduce only if it's the blue die
        if Global.mech_dice_current_amount > 0:
            Global.mech_dice_current_amount -= 1
            dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
    update_selected_highlight()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_dice_1_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0 && Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("blue")
        Events.update_roll_history_ui.emit()
        


func _on_dice_2_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("red")
        Global.dice_type = "red"
        Events.reset_charged_card.emit()
        Events.update_roll_history_ui.emit()
        
func _on_dice_3_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("evil")
        Global.dice_type = "evil"
        Events.update_roll_history_ui.emit()
        
func _on_dice_4_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("giant")
        Global.dice_type = "giant"
        Events.update_roll_history_ui.emit()
        
func _on_dice_5_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("magma")
        Global.dice_type = "magma"
        Events.update_roll_history_ui.emit()      
        
func _on_dice_6_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("even")
        Global.dice_type = "even"
        Events.update_roll_history_ui.emit()
        
func _on_dice_7_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("odd")
        Global.dice_type = "odd"
        Events.update_roll_history_ui.emit()  
        
func _on_dice_8_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("green")
        Global.dice_type = "green"
        Events.update_roll_history_ui.emit()

func _on_dice_9_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Global.power_at_last_switch = Global.roll_value
        Events.active_dice_changed.emit("mech")
        Global.dice_type = "mech"
        Events.update_roll_history_ui.emit()

        
        
        
        
func _on_player_turn_ended() -> void:
    # Bank whatever Golem Dice the player didn't spend, for the next turn's refill to add on.
    # Read at turn END rather than at the next turn's start so a shop purchase (which does
    # `current += 1` between fights) can never be mistaken for a leftover - see the comment
    # on Global.golem_dice_carryover.
    # Explicit int: Global's dice counters are untyped, so `:=`/maxi() can't infer from them.
    var leftover: int = Global.even_dice_current_amount
    Global.golem_dice_carryover = maxi(0, leftover)
    # "Keep your Dice" card: same idea as Golem's carryover but for EVERY type, for one turn.
    # Golem is excluded - it already carries, and stacking both would double its leftovers.
    Global.kept_dice = {}
    # keep_all_dice_always is the Golem Heart relic: same stash, but permanent instead of the
    # card's one-shot. Checked with OR so owning the relic and playing the card in the same
    # turn can't double-bank (the stash is a snapshot of what's left, not an increment).
    if Global.keep_all_dice_next_turn or Global.keep_all_dice_always:
        Global.keep_all_dice_next_turn = false
        for type in Global.DICE_TYPE_ORDER:
            if type == "even":
                continue
            var amount: int = Global.get(type + "_dice_current_amount")
            if amount > 0:
                Global.kept_dice[type] = amount


func _on_player_turn_started() -> void:
    Global.blue_dice_current_amount = Global.blue_dice_max_amount + Global.blue_dice_bonus_amount + Global.blue_dice_bonus_amount_fight
    Global.red_dice_current_amount = Global.red_dice_max_amount + Global.red_dice_bonus_amount
    Global.evil_dice_current_amount = Global.evil_dice_max_amount + Global.evil_dice_bonus_amount
    Global.green_dice_current_amount = Global.green_dice_max_amount + Global.green_dice_bonus_amount
    Global.giant_dice_current_amount = Global.giant_dice_max_amount + Global.giant_dice_bonus_amount
    Global.magma_dice_current_amount = Global.magma_dice_max_amount + Global.magma_dice_bonus_amount
    # Golem Dice: the one type that does NOT simply reset to max+bonus. Whatever went
    # unspent last turn (captured in _on_player_turn_ended) is added on top. No cap - the
    # cost of hoarding is the tempo you gave up to do it.
    # A NEGATIVE bonus (Depleted from Electrify, the Dicelord's Dice Theft) eats into the
    # carried dice like it eats into any other type's refill, hence the single clamp over
    # the whole sum rather than protecting the carry: "you have 1 less Dice next turn"
    # stays honest, and banking dice can't be used to dodge the debuff.
    Global.even_dice_current_amount = maxi(0,
            Global.even_dice_max_amount + Global.even_dice_bonus_amount
            + Global.golem_dice_carryover)
    Global.golem_dice_carryover = 0
    Global.odd_dice_current_amount = Global.odd_dice_max_amount + Global.odd_dice_bonus_amount
    Global.mech_dice_current_amount = Global.mech_dice_max_amount + Global.mech_dice_bonus_amount + Global.mech_dice_bonus_amount_fight

    # "Keep your Dice" card: leftovers stashed at turn end (see _on_player_turn_ended) are
    # added on top of the normal refill, then cleared. A one-shot, unlike Golem's permanent
    # carryover - and Golem is excluded from the stash so the two can't double up.
    for kept_type in Global.kept_dice:
        Global.set(kept_type + "_dice_current_amount",
                Global.get(kept_type + "_dice_current_amount") + Global.kept_dice[kept_type])
    Global.kept_dice = {}

    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)

    Global.roll_history = []
    Events.update_roll_history_ui.emit()

    Global.blue_dice_bonus_amount = 0
    Global.red_dice_bonus_amount = 0
    Global.evil_dice_bonus_amount = 0
    Global.green_dice_bonus_amount = 0
    Global.giant_dice_bonus_amount = 0
    Global.magma_dice_bonus_amount = 0
    Global.even_dice_bonus_amount = 0
    Global.odd_dice_bonus_amount = 0
    Global.mech_dice_bonus_amount = 0
    Global.charged_dice_this_turn = false
    Global.echo_chamber_fired_this_turn = false
    initialize_dices()
    update_selected_highlight()
    _play_panel_refill_burst()

func _on_hover_playable_cards() -> void:
    update_selected_highlight()

func _on_dice_amount_changed():
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
    update_selected_highlight()

func initialize_dices():
    # Blue used to be assumed permanent and stayed always-visible, but a run loadout
    # (dice_loadout.gd, run #2+) can start a run with no Blue at all - so Blue gets the
    # same show/hide check as Red (tradeable away via event_hollow_idol.gd) and every
    # other type below. bonus_amount_fight is part of Blue's check because Emanation
    # grants fight-scoped Blue dice to players who may own none.
    if Global.blue_dice_max_amount > 0 or Global.blue_dice_current_amount > 0 or Global.blue_dice_bonus_amount > 0 or Global.blue_dice_bonus_amount_fight > 0:
        dice_1.show()
    else:
        dice_1.hide()

    if Global.red_dice_max_amount > 0 or Global.red_dice_current_amount > 0 or Global.red_dice_bonus_amount > 0:
        dice_2.show()
    else:
        dice_2.hide()

    if Global.evil_dice_max_amount > 0 or Global.evil_dice_current_amount > 0 or Global.evil_dice_bonus_amount > 0:
        print("evil dice appearing")
        dice_3_texture.texture = load("res://assets/images/evil6.png")
        dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
        dice_3.show()
    else:
        dice_3.hide()

    if Global.giant_dice_max_amount > 0 or Global.giant_dice_current_amount > 0 or Global.giant_dice_bonus_amount > 0:
        print("giant dice appearing")
        dice_4_texture.texture = load("res://assets/images/giant12.png")
        dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
        dice_4.show()
    else:
        dice_4.hide()

    if Global.magma_dice_max_amount > 0 or Global.magma_dice_current_amount > 0 or Global.magma_dice_bonus_amount > 0:
        print("magma dice appearing")
        dice_5_texture.texture = load("res://assets/images/magma6.png")
        dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
        dice_5.show()
    else:
        dice_5.hide()

    if Global.even_dice_max_amount > 0 or Global.even_dice_current_amount > 0 or Global.even_dice_bonus_amount > 0:
        print("even dice appearing")
        dice_6_texture.texture = load("res://assets/images/even8.png")
        dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
        dice_6.show()
    else:
        dice_6.hide()

    if Global.odd_dice_max_amount > 0 or Global.odd_dice_current_amount > 0 or Global.odd_dice_bonus_amount > 0:
        print("odd dice appearing")
        dice_7_texture.texture = load("res://assets/images/odd7.png")
        dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
        dice_7.show()
    else:
        dice_7.hide()

    if Global.green_dice_max_amount > 0 or Global.green_dice_current_amount > 0 or Global.green_dice_bonus_amount > 0:
        print("green dice appearing")
        dice_8_texture.texture = load("res://assets/images/green1.png")
        dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
        dice_8.show()
    else:
        dice_8.hide()
    
    if Global.mech_dice_max_amount > 0 or Global.mech_dice_current_amount > 0 or Global.mech_dice_bonus_amount > 0 or Global.mech_dice_bonus_amount_fight > 0:
        print("mech dice appearing")
        dice_9_texture.texture = load("res://assets/images/mech1.png")
        dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
        dice_9.show()
    else:
        dice_9.hide()
        
func add_dice_slot(dice_type: String) -> int:
    var textures = [dice_1_texture, dice_2_texture, dice_3_texture, dice_4_texture, dice_5_texture, dice_6_texture, dice_7_texture,dice_8_texture]
    
    for i in textures.size():
        if textures[i].texture == null:
            print("Available slot:", i)
            textures[i].texture = load("res://assets/images/evil6.png")
            var dice_node = get_node("DicePanel/MarginContainer/HBoxContainer/Dice" + str(i+1))
            dice_node.show()
            return i  # First available slot
    print("No available dice slots!")
    return -1  # No available slots

func _on_dice_bought(dice_type):
    print("bought ", dice_type)
    SFXPlayer.play(Global.sfx_click)
    add_dice_slot(dice_type)

func _on_resize_dice_interface():
    _resize_panel_for_dice_inventory()

func _resize_panel_for_dice_inventory() -> void:
    # Count slots that are actually visible right now (mirrors
    # initialize_dices()'s own per-type conditions) rather than relying on
    # Global.dice_inventory, which most temporary-dice-granting cards never
    # update (only cogwork.gd does) and is therefore frequently stale.
    var visible_dice_count := 0
    if Global.blue_dice_max_amount > 0 or Global.blue_dice_current_amount > 0 or Global.blue_dice_bonus_amount > 0 or Global.blue_dice_bonus_amount_fight > 0:
        visible_dice_count += 1
    if Global.red_dice_max_amount > 0 or Global.red_dice_current_amount > 0 or Global.red_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.evil_dice_max_amount > 0 or Global.evil_dice_current_amount > 0 or Global.evil_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.giant_dice_max_amount > 0 or Global.giant_dice_current_amount > 0 or Global.giant_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.magma_dice_max_amount > 0 or Global.magma_dice_current_amount > 0 or Global.magma_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.even_dice_max_amount > 0 or Global.even_dice_current_amount > 0 or Global.even_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.odd_dice_max_amount > 0 or Global.odd_dice_current_amount > 0 or Global.odd_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.green_dice_max_amount > 0 or Global.green_dice_current_amount > 0 or Global.green_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.mech_dice_max_amount > 0 or Global.mech_dice_current_amount > 0 or Global.mech_dice_bonus_amount > 0 or Global.mech_dice_bonus_amount_fight > 0:
        visible_dice_count += 1
    dice_panel.custom_minimum_size.x = (visible_dice_count * 65) + 20
    # The corner-accent frame art (swapped in 2026-08-16) has a much thicker painted
    # border than the old thin-rim tray, which visually cramped the dice. Grow the
    # plate 8px past the control on both vertical sides to give them air again.
    # (Idempotent - this runs on every inventory refresh.)
    dice_panel.offset_top = -8.0
    dice_panel.offset_bottom = 8.0

func _on_card_played_for_charge(_card) -> void:
    _last_card_play_frame = Engine.get_process_frames()


func _on_dice_charged(charged_type: String, count: int) -> void:
    # State first, ceremony second: labels/visibility reflect the new counts immediately.
    # initialize_dices() only rewrites the optional types' labels - blue (dice_1) and red
    # (dice_2) get visibility handling there but not label text, so charging blue/red
    # (Disintegrate on the active blue die, Spark, Blood Drop...) needs the manual refresh.
    var slot: Control = _slot_for_type(charged_type)
    var was_visible: bool = slot != null and slot.visible
    initialize_dices()
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    _resize_panel_for_dice_inventory()
    animation_player.play("charge")  # panel-wide ripple, kept as the "panel notices" layer

    var newly_visible: bool = slot != null and slot.visible and not was_visible and count > 0
    if newly_visible and slot not in _materializing_slots:
        # A brand-new die type! Hold the slot invisible (alpha only - visible=true keeps its
        # layout space reserved, so nothing reflows when it blooms in) until the first
        # delivered die arrives: the materialization IS the arrival.
        _materializing_slots.append(slot)
        slot.modulate = Color(1, 1, 1, 0)
    update_selected_highlight()

    if count <= 0 or slot == null:
        # Nothing will fly: an empty Transmutation (count 0, which the die's listener
        # filters anyway), or a type with no slot at all. In the latter case dice really
        # were granted, so the die still owes an acknowledgement - and with no flight, the
        # payoff moment is now (same reasoning as the no-ui_layer fallback below).
        if count > 0:
            _emit_charge_delivered(charged_type, count, _begin_charge_volley_token())
        return
    _play_charge_launch_sound()
    _spawn_charge_volley(charged_type, count, _charge_origin(),
            _next_volley_delay(count), newly_visible, _begin_charge_volley_token())

func _on_temporary_dice_added(dice_type: String):
    initialize_dices()  # Refresh the interface
    _resize_panel_for_dice_inventory()

func _show_tooltip(dice_node: VBoxContainer, dice_type: String) -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
    tooltip_instance = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance, self)
    var tooltip_panel = tooltip_instance.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content(dice_type)
    tooltip_panel.show_tooltip_above(DICE_TOOLTIP_BOTTOM, DICE_TOOLTIP_CENTER_X, DICE_TOOLTIP_MIN_TOP)

func _hide_tooltip() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null


# Combat can end (or the view can be swapped) while a dice slot is hovered - mouse_exited
# never fires on a node being destroyed, and the tooltip lives on the tree root, so without
# this it outlives the battle. Same bug class as shop.gd's dice tooltips.
func _exit_tree() -> void:
    _hide_tooltip()
        
        

func _on_dice_1_mouse_entered() -> void:
    _show_tooltip(dice_1, "blue")
func _on_dice_1_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_2_mouse_entered() -> void:
    _show_tooltip(dice_2, "red")
func _on_dice_2_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_3_mouse_entered() -> void:
    _show_tooltip(dice_3, "evil")
func _on_dice_3_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_4_mouse_entered() -> void:
    _show_tooltip(dice_4, "giant")
func _on_dice_4_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_5_mouse_entered() -> void:
    _show_tooltip(dice_5, "magma")
func _on_dice_5_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_6_mouse_entered() -> void:
    _show_tooltip(dice_6, "even")
func _on_dice_6_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_7_mouse_entered() -> void:
    _show_tooltip(dice_7, "odd")
func _on_dice_7_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_8_mouse_entered() -> void:
    _show_tooltip(dice_8, "green")
func _on_dice_8_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_9_mouse_entered() -> void:
    _show_tooltip(dice_9, "mech")
func _on_dice_9_mouse_exited() -> void:
    _hide_tooltip()


func update_selected_highlight(selected_type: String = Global.dice_type) -> void:
    var active_empty: bool = Global.get(DICE_TYPE_TO_AMOUNT.get(selected_type, "blue_dice_current_amount")) <= 0
    # Nudge toward another die only once the current die is spent AND no Power is banked -
    # otherwise it nags "switch to me!" while you still have Power to spend on a card first
    # (you rolled blue, blue's now empty, but you're about to Strike with that Power). Once
    # a card consumes the Power (roll_value -> 0), hover_playable_cards fires and the nudge
    # kicks in. Suppressed during the tutorial - it gates/spotlights slots itself.
    var want_nudge := active_empty and Global.roll_value <= 0 and not Global.tutorial_on

    # Which slots should be pulsing this pass (deterministic dict order, so the array can be
    # compared by value below).
    var new_nudge: Array = []
    if want_nudge:
        for dice_type in DICE_TYPE_TO_NODE:
            if dice_type == selected_type:
                continue
            var n = get(DICE_TYPE_TO_NODE[dice_type])
            if Global.get(DICE_TYPE_TO_AMOUNT[dice_type]) > 0 and n.visible \
                    and n not in _materializing_slots:
                new_nudge.append(n)

    # Only tear down / rebuild the looping pulses when the SET actually changes, so the
    # frequent refresh signals this listens to (rolls, power changes, switches) can't
    # restart the breathing animation every time. A pulsing slot's modulate/scale are owned
    # by its tween, so those nodes are skipped in the styling loop while their set holds.
    var nudge_changed: bool = new_nudge != _nudge_nodes
    if nudge_changed:
        for t in _nudge_tweens:
            if t and t.is_valid():
                t.kill()
        _nudge_tweens.clear()
        _nudge_nodes = new_nudge

    for dice_type in DICE_TYPE_TO_NODE:
        var node = get(DICE_TYPE_TO_NODE[dice_type])
        if node in _materializing_slots:
            continue  # mid charge-delivery reveal: its alpha is owned by the delivery
        if node in _nudge_nodes:
            if nudge_changed:
                _start_nudge_pulse(node)
            continue
        var amount: int = Global.get(DICE_TYPE_TO_AMOUNT[dice_type])
        var depleted := amount <= 0
        if dice_type == selected_type and not depleted:
            var base_color: Color = DicePalette.accent(dice_type)
            var highlight := base_color.lerp(Color.WHITE, 0.55)
            node.modulate = Color(highlight.r * 1.3, highlight.g * 1.3, highlight.b * 1.3, 1.0)
            node.scale = Vector2(1.15, 1.15)
        elif depleted:
            node.modulate = Color(0.32, 0.32, 0.32, 0.55)
            node.scale = Vector2(1.0, 1.0)
        else:
            node.modulate = Color(0.72, 0.72, 0.72, 1.0)
            node.scale = Vector2(1.0, 1.0)


# Soft looping "I'm still ready" pulse on an available slot while the active die is out
# of rolls. Deliberately subtle: a warm brightening from the idle gray plus a whisper of
# scale - the gold-ish tint matches the game's established "actionable" language (End
# Turn pulse, tutorial glow) without competing with the selected slot's accent pop.
func _start_nudge_pulse(node: Control) -> void:
    node.pivot_offset = node.size / 2.0
    var tween := create_tween().set_loops()
    tween.tween_property(node, "modulate", Color(1.12, 1.05, 0.85, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.parallel().tween_property(node, "scale", Vector2(1.06, 1.06), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(node, "modulate", Color(0.72, 0.72, 0.72, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.parallel().tween_property(node, "scale", Vector2(1.0, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _nudge_tweens.append(tween)


# Small "back up!" punch played on a dice slot that just got refilled from
# empty at the start of a turn. Plays after update_selected_highlight() has
# "Dice are back!" punch played on the whole dice panel at the start of every
# turn, regardless of what was depleted last turn — simpler and more readable
# than animating individual slots, and reads as "your resources just refreshed."
func _play_panel_refill_burst() -> void:
    dice_panel.pivot_offset = dice_panel.size / 2.0
    var resting_modulate: Color = dice_panel.modulate
    var tween := create_tween()
    tween.tween_property(dice_panel, "scale", Vector2(1.12, 1.12), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_panel, "modulate", Color(1.6, 1.6, 1.6, resting_modulate.a), 0.1)
    tween.tween_property(dice_panel, "scale", Vector2(1.0, 1.0), 0.22) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_panel, "modulate", resting_modulate, 0.28)


# ── Charge delivery internals ──────────────────────────────────────────────────────────


func _slot_for_type(dice_type: String) -> Control:
    if DICE_TYPE_TO_NODE.has(dice_type):
        return get(DICE_TYPE_TO_NODE[dice_type])
    return null


func _slot_texture_for_type(dice_type: String) -> TextureRect:
    if DICE_TYPE_TO_NODE.has(dice_type):
        return get(DICE_TYPE_TO_NODE[dice_type] + "_texture")
    return null


func _charge_die_texture(dice_type: String) -> Texture2D:
    # The slot's own art guarantees "the die that flew in IS the die in the slot" (and it's
    # already set by the initialize_dices() call at emit time, even for a brand-new slot).
    var slot_tex := _slot_texture_for_type(dice_type)
    if slot_tex != null and slot_tex.texture != null:
        return slot_tex.texture
    return load("res://assets/images/%s.png" % CHARGE_FALLBACK_FACE.get(dice_type, "blue6"))


func _play_charge_launch_sound() -> void:
    # One launch sound per frame no matter how many charge events fire together (Experiment
    # and War Ritual emit once PER die) - the arrival clinks carry the rest of the audio.
    var f := Engine.get_process_frames()
    if f == _charge_sound_frame:
        return
    _charge_sound_frame = f
    SFXPlayer.play(CHARGE_LAUNCH_SOUND, false, 1.0, 4.0)


# Same-frame volleys (multi-type charges) queue one after another instead of overlapping,
# so a random multi-charge reads as a SEQUENCE of typed deliveries - the reveal moment.
func _next_volley_delay(count: int) -> float:
    var f := Engine.get_process_frames()
    if f != _charge_volley_frame:
        _charge_volley_frame = f
        _charge_volley_delay = 0.0
    var my_delay := _charge_volley_delay
    _charge_volley_delay += CHARGE_STAGGER * mini(count, CHARGE_MAX_ICONS)
    return my_delay


# Opens a volley's exactly-once token. Every path that will eventually announce a delivery
# takes one here, so _emit_charge_delivered stays the single door to the signal.
func _begin_charge_volley_token() -> int:
    _charge_volley_seq += 1
    _pending_charge_volleys[_charge_volley_seq] = true
    return _charge_volley_seq


# Exactly-once per volley: the last arrival callback and the failsafe timer both funnel
# through here, so whichever runs first wins and the other is a no-op (same shape as the
# _finish_slot_materialize failsafe). dice.gd keys the big die's whole charge response on
# this, so a double emit would double-pulse and a lost emit would silence the charge.
func _emit_charge_delivered(charged_type: String, count: int, token: int) -> void:
    if not _pending_charge_volleys.has(token):
        return
    _pending_charge_volleys.erase(token)
    Events.dice_charge_delivered.emit(charged_type, count)


func _charge_origin() -> Vector2:
    # Mirror of the power-orb origin rules (dice.gd): a card launches from where it was
    # released; the red-socket path and every non-card source (relics, statuses, the
    # Sigil/Gnome triggers) launch from the active die.
    if not Global.playing_red_card \
            and Engine.get_process_frames() == _last_card_play_frame \
            and Global.last_played_card_position != Vector2.ZERO:
        return Global.last_played_card_position
    return _active_die_center()


func _active_die_center() -> Vector2:
    # ActiveDice is this node's sibling in battle.tscn; its dice_display is the die art.
    var die := get_node_or_null("../ActiveDice")
    if die != null and "dice_display" in die and die.dice_display != null:
        return die.dice_display.get_global_rect().get_center()
    # Boot-order / harness fallback: a spot under the slot row.
    return dice_panel.get_global_rect().get_center() + Vector2(0.0, 140.0)


func _spawn_charge_volley(charged_type: String, count: int, origin: Vector2,
        base_delay: float, reveal_slot: bool, token: int) -> void:
    # One frame so a slot that JUST went visible has been sorted by its container - its
    # global rect is stale until then and every flight would aim at the pre-sort position.
    await get_tree().process_frame
    if not is_inside_tree():
        return
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    var n := mini(count, CHARGE_MAX_ICONS)
    if parent_layer == null:
        # No flight possible (harness/boot without BattleUI): never leave a slot dark, and
        # still hand the big die its cue - with nothing to fly, "delivered" is now.
        if reveal_slot:
            _finish_slot_materialize(_slot_for_type(charged_type), charged_type)
        _emit_charge_delivered(charged_type, count, token)
        return
    var accent := DicePalette.accent(charged_type)
    for i in n:
        _animate_charge_die(parent_layer, charged_type, origin, accent,
                base_delay + CHARGE_STAGGER * i + randf_range(0.0, 0.04),
                i, n, reveal_slot and i == 0, count, token)
    var total := base_delay + CHARGE_STAGGER * n + CHARGE_BIRTH_TIME + CHARGE_FLIGHT_TIME
    if reveal_slot:
        # Failsafe: if the first arrival callback is ever lost, the slot must still bloom
        # in rather than sit invisible forever. Idempotent via the _materializing check.
        get_tree().create_timer(total + 1.0, false).timeout.connect(
                _finish_slot_materialize.bind(_slot_for_type(charged_type), charged_type))
    # Same failsafe for the big die's cue: a lost last-arrival callback must not leave the
    # charge with no pulse at all. Idempotent via the pending-token guard.
    get_tree().create_timer(total + 1.0, false).timeout.connect(
            _emit_charge_delivered.bind(charged_type, count, token))


func _animate_charge_die(parent_layer: Node, charged_type: String, origin: Vector2,
        accent: Color, delay: float, index: int, total: int, reveal_on_arrival: bool,
        full_count: int, token: int) -> void:
    var icon := TextureRect.new()
    icon.texture = _charge_die_texture(charged_type)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(CHARGE_ICON_SIZE, CHARGE_ICON_SIZE)
    icon.size = Vector2(CHARGE_ICON_SIZE, CHARGE_ICON_SIZE)
    icon.pivot_offset = icon.size / 2.0
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.z_index = 150  # ui_layer flourish convention (refuel return / thrown dice)
    icon.set_meta("accent", accent)  # read back by _charge_flight_step for the mote trail
    parent_layer.add_child(icon)

    # Soft accent halo behind the die - a DELIVERED die glows like a gift, which is also
    # what separates it at a glance from a THROWN die (attack) crossing the same screen.
    var glow := TextureRect.new()
    glow.texture = DicePalette.glow_texture()
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var glow_size := CHARGE_ICON_SIZE * 2.1
    glow.size = Vector2(glow_size, glow_size)
    glow.position = -Vector2(glow_size - CHARGE_ICON_SIZE, glow_size - CHARGE_ICON_SIZE) / 2.0
    glow.material = DicePalette.additive_material()
    glow.modulate = Color(accent.r, accent.g, accent.b, 0.72)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.show_behind_parent = true
    icon.add_child(glow)

    # Target captured now - one frame after the visibility refresh (see the await in
    # _spawn_charge_volley), so container layout has settled.
    var slot_tex := _slot_texture_for_type(charged_type)
    var target: Vector2
    if slot_tex != null:
        target = slot_tex.get_global_rect().get_center()
    else:
        target = dice_panel.get_global_rect().get_center()
    var spawn := origin + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 6.0))
    # Birth lifts up out of the card so the launch reads on top of the card art, then the
    # arc control point sits above the straight midpoint, jittered per die so a volley
    # never moves in lockstep (the power-orb "train" lesson).
    var lift := spawn + Vector2(randf_range(-10.0, 10.0), -44.0)
    var mid := lift.lerp(target, randf_range(0.42, 0.58))
    var ctrl := mid + Vector2(randf_range(-60.0, 60.0), -randf_range(50.0, 110.0))

    icon.global_position = spawn - icon.size / 2.0
    icon.scale = Vector2.ZERO

    var tween := icon.create_tween()
    tween.tween_interval(maxf(delay, 0.001))
    if index == 0:
        # Departure beat: the source visibly EJECTS the dice instead of them just appearing.
        # Only on the first die of a volley - one launch, many dice.
        tween.tween_callback(_spawn_launch_flare.bind(parent_layer, spawn, accent))
    # Birth: pop + lift out of the card.
    tween.tween_property(icon, "scale", Vector2.ONE, CHARGE_BIRTH_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(icon, "global_position", lift - icon.size / 2.0, CHARGE_BIRTH_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    # Flight: accelerating bezier arc into the slot ("pulled in"), trailing motes.
    tween.tween_method(
            _charge_flight_step.bind(icon, lift, ctrl, target),
            0.0, 1.0, CHARGE_FLIGHT_TIME + randf_range(-0.05, 0.05)) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(_on_charge_die_arrived.bind(
            icon, charged_type, accent, index, total, reveal_on_arrival, full_count, token))


func _charge_flight_step(t: float, icon: TextureRect, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
    if not is_instance_valid(icon):
        return
    var a := p0.lerp(p1, t)
    var b := p1.lerp(p2, t)
    var pos := a.lerp(b, t)
    icon.global_position = pos - icon.size / 2.0
    # Slight swell mid-arc, shrinking toward the slot so it reads as sinking IN.
    var s := 1.0 + 0.14 * sin(t * PI) - 0.22 * t
    icon.scale = Vector2(s, s)
    # Real-time throttle (t is eased - gating on t would clump motes near the start).
    var now := Time.get_ticks_msec()
    var last: int = icon.get_meta("trail_ms", 0)
    if now - last >= CHARGE_TRAIL_INTERVAL_MS:
        icon.set_meta("trail_ms", now)
        var accent: Color = icon.get_meta("accent", Color.WHITE)
        _spawn_charge_mote(icon.get_parent(), pos, accent, false)


func _on_charge_die_arrived(icon: TextureRect, charged_type: String, accent: Color,
        index: int, total: int, reveal: bool, full_count: int, token: int) -> void:
    if is_instance_valid(icon):
        icon.queue_free()
    # Rising pitch through the volley - the free "Charge 1 vs Charge 4" ladder - with a
    # heavier clack layered on the last arrival.
    SFXPlayer.play(CHARGE_ARRIVE_SOUND, false, 1.15 + 0.09 * index, -6.0, -1)
    var final_die := index == total - 1
    if final_die:
        SFXPlayer.play(CHARGE_FINAL_SOUND, false, 1.3, -8.0)
        # THE beat (2026-08-28): the big die's gust/flash/absorb hangs off this, so the
        # eruption lands on the same frame as the clack, the panel kick and the hit-stop
        # below instead of firing at launch and being over before anything arrived.
        # Emitted BEFORE the hit-stop so the listener's tweens are built in the same frame
        # the freeze starts - the gust's bright rise then plays out inside it, on purpose.
        _emit_charge_delivered(charged_type, full_count, token)
    if reveal:
        _finish_slot_materialize(_slot_for_type(charged_type), charged_type)
    var slot_tex := _slot_texture_for_type(charged_type)
    if slot_tex == null or not is_instance_valid(slot_tex):
        return
    var rect := slot_tex.get_global_rect()
    var center := rect.get_center()
    # Layered exactly like the thrown-die bash: soft shock ring (mass, low alpha so a volley
    # can't overexpose) -> bright short flare (force) -> overbright ghost of the die -> a
    # spray of motes. Any one of these alone reads as "a small light blinked".
    _spawn_slot_shock(center, accent, final_die)
    _spawn_slot_flash(rect, accent, final_die)
    _spawn_slot_ghost(slot_tex, rect, final_die)
    var burst: int = CHARGE_ARRIVAL_MOTES
    if final_die:
        burst = int(burst * 1.8)
    _spawn_arrival_motes(center, accent, burst)
    # The COUNT is the actual payload of a charge - punch the number, not just the art.
    _punch_slot_label(charged_type, accent)
    # Panel kick on the LAST die only. A nudge per die made the whole row jitter through a
    # volley, which competes with the shockwave for "this is the big moment".
    if final_die:
        _kick_panel(0.04 + 0.01 * float(mini(total, 4)))
    if final_die:
        # Only the LAST arrival freezes - one hit-stop per volley, scaled by how much
        # landed. Per-die freezes would read as stutter, not weight. The cooldown covers
        # the other stutter source: a multi-type charge (Experiment, War Ritual) is N
        # separate one-die volleys, which would otherwise chain N freezes back to back.
        var now := Time.get_ticks_msec()
        if now - _last_hit_stop_ms >= CHARGE_HIT_STOP_COOLDOWN_MS:
            _last_hit_stop_ms = now
            Shaker.hit_stop(clampf(0.05 + 0.012 * float(total), 0.05, 0.11),
                    CHARGE_HIT_STOP_SCALE)


# Die-silhouette flash over the slot (die_halo_texture follows the square die shape) -
# accent-colored so the beat carries the charged type's identity.
func _spawn_slot_flash(rect: Rect2, accent: Color, big: bool) -> void:
    var flash := TextureRect.new()
    flash.texture = DicePalette.die_halo_texture()
    flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var d := maxf(rect.size.x, rect.size.y)
    var s := d * (2.9 if big else 2.2)
    flash.size = Vector2(s, s)
    flash.pivot_offset = flash.size / 2.0
    flash.material = DicePalette.additive_material()
    # Tinted toward white-hot rather than pure accent: a saturated accent flash reads as
    # "a colored blob", a white-hot core tinted by the accent reads as force (the same
    # split the thrown-die flare uses).
    var hot := Color(accent.r + 0.45, accent.g + 0.45, accent.b + 0.45, 0.0)
    flash.modulate = hot
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(flash)  # sibling drawn after DicePanel -> renders above the slots
    flash.global_position = rect.get_center() - flash.size / 2.0
    flash.scale = Vector2(0.5, 0.5)
    # TWO tweens on purpose: alpha must snap to peak and start decaying IMMEDIATELY while
    # the ring keeps expanding. Putting both on one tween (parallel scale, then chained
    # fade) holds full white for the whole expansion - measured 0.3-0.5s of blown-out slot,
    # which reads as a wash rather than a hit (additive-stacking trap). The alpha tween owns
    # the lifetime; freeing the node kills the scale tween with it.
    var peak := 0.95 if big else 0.7
    var ft := flash.create_tween()
    ft.tween_property(flash, "modulate:a", peak, 0.035) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    ft.tween_property(flash, "modulate:a", 0.0, 0.17) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    ft.tween_callback(flash.queue_free)
    var fs := flash.create_tween()
    fs.tween_property(flash, "scale", Vector2.ONE, 0.26) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# White-hot pop at the launch point (card release / active die) as the dice are ejected.
func _spawn_launch_flare(parent: Node, pos: Vector2, accent: Color) -> void:
    if parent == null or not is_instance_valid(parent):
        return
    var flare := TextureRect.new()
    flare.texture = DicePalette.glow_texture()
    flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    flare.size = Vector2(110.0, 110.0)
    flare.pivot_offset = flare.size / 2.0
    flare.material = DicePalette.additive_material()
    flare.modulate = Color(accent.r + 0.5, accent.g + 0.5, accent.b + 0.5, 0.9)
    flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flare.z_index = 149
    flare.set_meta("accent", accent)  # also what the harness leak check counts
    parent.add_child(flare)
    flare.global_position = pos - flare.size / 2.0
    flare.scale = Vector2(0.3, 0.3)
    var tw := flare.create_tween()
    tw.set_parallel(true)
    tw.tween_property(flare, "scale", Vector2(1.35, 1.35), 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(flare, "modulate:a", 0.0, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(flare.queue_free)
    for i in 6:
        var mote := _spawn_charge_mote(parent, pos, accent, true)
        if mote == null:
            continue
        var dest := pos + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(18.0, 48.0)
        var mt := mote.create_tween()
        mt.set_parallel(true)
        mt.tween_property(mote, "global_position", dest - mote.size / 2.0, 0.32) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        mt.tween_property(mote, "modulate:a", 0.0, 0.32)
        mt.chain().tween_callback(mote.queue_free)


# Soft expanding ring at the slot - the MASS layer under the flash. Deliberately low alpha
# so a 6-die volley stacking additively can't white out the panel (documented trap).
func _spawn_slot_shock(center: Vector2, accent: Color, big: bool) -> void:
    var puff := TextureRect.new()
    puff.texture = DicePalette.glow_texture()
    puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    puff.size = Vector2(46.0, 46.0)
    puff.pivot_offset = puff.size / 2.0
    puff.material = DicePalette.additive_material()
    puff.modulate = Color(accent.r, accent.g, accent.b, 0.45)
    puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(puff)
    puff.global_position = center - puff.size / 2.0
    puff.scale = Vector2(0.5, 0.5)
    var tw := puff.create_tween()
    tw.tween_property(puff, "scale", Vector2.ONE * (3.0 if big else 2.2), 0.3) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.3) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(puff.queue_free)


# Spray of motes off the impact - the mass that makes the landing read. Biased UPWARD and
# outward (dice "splash" off the slot) rather than a symmetric ring, which would echo the
# shock puff's shape instead of adding to it.
func _spawn_arrival_motes(center: Vector2, accent: Color, count: int) -> void:
    for i in count:
        var mote := _spawn_charge_mote(self, center, accent, true)
        if mote == null:
            continue
        var ang := randf_range(-PI * 0.95, -PI * 0.05)  # upward fan
        var dist := randf_range(22.0, 62.0)
        var dest := center + Vector2.from_angle(ang) * dist + Vector2(0.0, randf_range(0.0, 12.0))
        var life := randf_range(0.3, 0.5)
        var mt := mote.create_tween()
        mt.set_parallel(true)
        mt.tween_property(mote, "global_position", dest - mote.size / 2.0, life) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        mt.tween_property(mote, "modulate:a", 0.0, life) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        mt.tween_property(mote, "scale", Vector2(0.35, 0.35), life) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        mt.chain().tween_callback(mote.queue_free)


# The count text IS the payload of a charge, so it gets its own beat. modulate carries the
# weight because a container re-sort can reset a child's scale but never its modulate.
func _punch_slot_label(charged_type: String, accent: Color) -> void:
    if not DICE_TYPE_TO_NODE.has(charged_type):
        return
    var label: Label = get(DICE_TYPE_TO_NODE[charged_type] + "_label")
    if label == null or not is_instance_valid(label):
        return
    label.pivot_offset = label.size / 2.0
    var flashed := Color(accent.r + 0.9, accent.g + 0.9, accent.b + 0.9, 1.0)
    var lt := label.create_tween()
    lt.set_parallel(true)
    lt.tween_property(label, "modulate", flashed, 0.05) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    lt.tween_property(label, "scale", Vector2(1.45, 1.45), 0.09) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    lt.chain().tween_property(label, "modulate", Color.WHITE, 0.26) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    lt.parallel().tween_property(label, "scale", Vector2.ONE, 0.26) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# Whole-panel thump on arrival. dice_panel is NOT inside a container (its scale survives),
# and the tween is tracked so a volley's overlapping kicks restart instead of fighting.
func _kick_panel(strength: float) -> void:
    if _panel_kick_tween and _panel_kick_tween.is_valid():
        _panel_kick_tween.kill()
    dice_panel.pivot_offset = dice_panel.size / 2.0
    var s := 1.0 + strength
    _panel_kick_tween = dice_panel.create_tween()
    _panel_kick_tween.tween_property(dice_panel, "scale", Vector2(s, s), 0.06) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _panel_kick_tween.tween_property(dice_panel, "scale", Vector2.ONE, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# Overbright ghost of the slot's die art popping off it - the arrival punch, done as a free
# overlay because the slot itself is a container child (containers own child transforms and
# a label change triggers a re-sort, the reward-card scale lesson).
func _spawn_slot_ghost(slot_tex: TextureRect, rect: Rect2, big: bool) -> void:
    var ghost := TextureRect.new()
    ghost.texture = slot_tex.texture
    ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ghost.size = rect.size
    ghost.pivot_offset = ghost.size / 2.0
    ghost.material = DicePalette.additive_material()
    var b := CHARGE_GHOST_BRIGHTNESS
    ghost.modulate = Color(b, b, b, 0.8)
    ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ghost)
    ghost.global_position = rect.position
    ghost.scale = Vector2(0.82, 0.82)  # snaps OUT from smaller-than-slot: reads as a burst
    var gt := ghost.create_tween()
    gt.set_parallel(true)
    gt.tween_property(ghost, "scale", Vector2(2.1, 2.1) if big else Vector2(1.7, 1.7), 0.26) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    gt.tween_property(ghost, "modulate:a", 0.0, 0.26) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    gt.chain().tween_callback(ghost.queue_free)


func _finish_slot_materialize(slot: Control, charged_type: String) -> void:
    if slot == null or not _materializing_slots.has(slot):
        return
    _materializing_slots.erase(slot)
    if not is_instance_valid(slot):
        return
    # Bloom in from overbright - "you now own a NEW die type (this fight)".
    var bt := slot.create_tween()
    bt.tween_property(slot, "modulate", Color(2.1, 2.1, 2.1, 1.0), 0.09) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    bt.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    bt.tween_callback(update_selected_highlight)
    # Celebration ring of motes around the newborn slot.
    var slot_tex := _slot_texture_for_type(charged_type)
    var center: Vector2
    if slot_tex != null:
        center = slot_tex.get_global_rect().get_center()
    else:
        center = slot.get_global_rect().get_center()
    var accent := DicePalette.accent(charged_type)
    for i in 8:
        var ang := TAU * i / 8.0 + randf_range(-0.25, 0.25)
        var mote := _spawn_charge_mote(self, center, accent, true)
        if mote != null:
            var dest := center + Vector2.from_angle(ang) * randf_range(26.0, 46.0)
            var mt := mote.create_tween()
            mt.set_parallel(true)
            mt.tween_property(mote, "global_position", dest - mote.size / 2.0, 0.4) \
                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            mt.tween_property(mote, "modulate:a", 0.0, 0.4) \
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
            mt.chain().tween_callback(mote.queue_free)


# One additive accent mote. Trail motes (still == false) get their own drift/fade tween
# here; burst motes (still == true) are returned inert for the caller to animate.
func _spawn_charge_mote(parent: Node, pos: Vector2, accent: Color, still: bool) -> TextureRect:
    if parent == null:
        return null
    var mote := TextureRect.new()
    mote.texture = DicePalette.glow_texture()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var msize := randf_range(12.0, 24.0)
    mote.size = Vector2(msize, msize)
    mote.pivot_offset = mote.size / 2.0
    mote.material = DicePalette.additive_material()
    mote.modulate = Color(accent.r, accent.g, accent.b, randf_range(0.6, 0.95))
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.z_index = 149  # just under the flying die
    mote.set_meta("accent", accent)  # also what the harness leak check counts
    parent.add_child(mote)
    mote.global_position = pos - mote.size / 2.0 \
            + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
    if not still:
        var mt := mote.create_tween()
        mt.set_parallel(true)
        mt.tween_property(mote, "modulate:a", 0.0, 0.38) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        mt.tween_property(mote, "scale", Vector2(0.3, 0.3), 0.38) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        mt.tween_property(mote, "global_position:y",
                mote.global_position.y - randf_range(6.0, 16.0), 0.38)
        mt.chain().tween_callback(mote.queue_free)
    return mote
