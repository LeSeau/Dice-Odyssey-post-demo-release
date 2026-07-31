class_name CardRewards
extends ColorRect

signal card_reward_selected(card: Card)

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

# --- Reveal ceremony -----------------------------------------------------------------------
# Staggered card entrance, mirroring battle_reward.gd's _animate_reward_entrance recipe
# (settle one frame -> center pivot -> alpha+scale tween). The resting scale is CAPTURED from
# the node after the settle frame instead of assumed - the Cards HBox / CardMenuUI
# CenterContainer pair owns what a card's resting transform actually is.
const REVEAL_BASE_DELAY := 0.22
const REVEAL_STAGGER := 0.16
const REVEAL_TIME := 0.3
const REVEAL_START_SCALE := 0.86
const REVEAL_SFX := preload("res://drawcardsound.wav")
const REVEAL_SFX_VOLUME_DB := -6.0
const REVEAL_SFX_PITCH_STEP := 0.07

# Gold beat when a Rare is revealed - the pity system's payoff moment. Flash color is well
# above 1.0 on purpose: modulate can only brighten pixels that aren't already at full white,
# and this card art is mostly dark - a mild 1.5x read as nothing in captures.
const RARE_FLASH_COLOR := Color(1.95, 1.65, 1.05)
const RARE_FLASH_IN_TIME := 0.1
const RARE_FLASH_OUT_TIME := 0.4
const RARE_MOTE_COUNT := 8
const RARE_MOTE_COLOR := Color(0.98, 0.82, 0.35)
const RARE_SFX := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const RARE_SFX_PITCH := 0.7
const RARE_SFX_VOLUME_DB := -2.0

# --- Pick beat -----------------------------------------------------------------------------
# Chosen card punches + flashes while the other two fall away, then a snapshot of the card
# flies to the top-bar deck button (teaches where drafted cards go). The selection signal is
# emitted at flight LAUNCH, not arrival - the deck badge updates while the card travels.
const PICK_HOLD := 0.32
const PICK_PUNCH_SCALE := 1.09
const PICK_SETTLE_SCALE := 1.03
const PICK_FLASH_COLOR := Color(1.5, 1.48, 1.35)
# Was dicerollsound3 (Julien, 2026-07-31: "dice roll sfx is weird") - nothing is being rolled
# here, and a rattle right after three card swishes read as a different game. The pick now
# uses the same card sample as the reveal and the deck arrival, pitched UP and louder: the
# whole ceremony becomes one instrument, "swish swish swish - SNAP - thunk". It also runs out
# (~1.1s) right as the card lands, so it never bleeds into the rewards screen behind.
# Unused one-line swaps if you want something more distinct: res://Item2A.wav (2.4s, too long
# to clear the landing), res://sounds/usedrunesound.wav (1.5s), res://sounds/nexteventsound.wav.
const PICK_SFX := preload("res://drawcardsound.wav")
const PICK_SFX_PITCH := 1.15
const PICK_SFX_VOLUME_DB := -2.0
const REJECT_TIME := 0.26
const REJECT_TINT := Color(0.6, 0.6, 0.6, 0.0)
const REJECT_SCALE := 0.93

const FLIGHT_LAYER := 90
const FLIGHT_TIME := 0.5
const FLIGHT_END_SCALE := 0.16
const FLIGHT_BANK_DEGREES := 14.0
const FLIGHT_FADE_TIME := 0.14
const FLIGHT_ARRIVE_SFX := preload("res://drawcardsound.wav")
const FLIGHT_ARRIVE_PITCH := 0.72
const FLIGHT_ARRIVE_VOLUME_DB := -6.0

@export var rewards: Array[Card] : set = set_rewards

@onready var cards: HBoxContainer = %Cards
@onready var skip_card_reward: Button = $VBoxContainer/SkipCardReward
@onready var card_menu_ai: CardMenuUI = $VBoxContainer/Cards/CardMenuAI
@onready var card_menu_ai_2: CardMenuUI = $VBoxContainer/Cards/CardMenuAI2
@onready var card_menu_ai_3: CardMenuUI = $VBoxContainer/Cards/CardMenuAI3


@onready var bonus_explanation_box: Panel = $VBoxContainer/CanvasLayer/BonusExplanationBox
@onready var bonus_explanation_box_2: Panel = $VBoxContainer/CanvasLayer/BonusExplanationBox2
@onready var blessing_explanation_box: Panel = $VBoxContainer/CanvasLayer/BlessingExplanationBox

# Paths fixed 2026-07-30: these pointed at $BonusExplanationBox/Button (root-relative), but
# the boxes live under VBoxContainer/CanvasLayer - every reward screen logged two "Node not
# found" errors since forever. The vars are unused (the buttons connect via scene signals),
# kept only because the wiring predates this pass.
@onready var button: Button = $VBoxContainer/CanvasLayer/BonusExplanationBox/Button
@onready var button_2: Button = $VBoxContainer/CanvasLayer/BonusExplanationBox2/Button2

# One pick per screen - set the instant a card is clicked, guards double-clicks on a second
# card (and Skip) during the pick beat.
var _picked := false
var _card_menus: Array[CardMenuUI] = []
var _intro_tweens: Array[Tween] = []
var _fx_tweens: Array[Tween] = []
var _live_motes: Array[Node] = []
# CardMenuUI -> Vector2 resting scale captured after the containers settled (see reveal note).
var _rest_scales := {}

static var _mote_texture: GradientTexture2D
static var _mote_material: CanvasItemMaterial


func _ready() -> void:
    clear_rewards()
    skip_card_reward.pressed.connect(_on_skip_pressed)


func _on_skip_pressed() -> void:
    if _picked:
        return
    card_reward_selected.emit(null)
    queue_free()


func clear_rewards() -> void:
    for card in cards.get_children():
        card.queue_free()
        bonus_explanation_box.visible = false
        blessing_explanation_box.visible = false


func set_rewards(new_cards: Array[Card]) -> void:
    rewards = new_cards

    if not is_node_ready():
        await ready

    clear_rewards()
    _card_menus.clear()
    _intro_tweens.clear()
    _fx_tweens.clear()
    _live_motes.clear()
    _rest_scales.clear()

    var has_bonus_requirement := false
    var has_transcendent_card := false
    var has_blessing_card := false
    var index := 0
    for card: Card in rewards:
        var new_card := CARD_MENU_UI.instantiate() as CardMenuUI
        cards.add_child(new_card)
        new_card.card = card

        # 🔥 Make it bigger by scaling its visuals
        new_card.get_node("Visuals").scale = Vector2(1.5, 1.5)  # Adjust the factor as needed

        # Connect click
        new_card.get_node("Visuals").gui_input.connect(_on_card_menu_clicked.bind(new_card, card))
        _card_menus.append(new_card)

        # Staggered reveal - alpha 0 NOW (before this node's first drawn frame), the entrance
        # coroutine pops it in on its stagger slot.
        new_card.modulate.a = 0.0
        _animate_card_entrance(new_card, index, card.rarity_tier == Card.RarityTier.RARE)
        index += 1

        # Check if this card has a bonus requirement
        if card.can_play_without_dice:
            has_transcendent_card = true
        if card.bonus_requirement != Card.Requirement.NONE:
            has_bonus_requirement = true
        if card.type == Card.Type.BLESSING:
            has_blessing_card = true

    # Bonus-effect tutorial disabled for now (kept below, commented out, not deleted) - only
    # 3-4 draftable cards currently use bonus_requirement, so this rarely triggers anyway.
    # Julien plans to make more bonus-effect cards draftable in a future pass; re-enable this
    # once that's done rather than deleting it.
    #if has_bonus_requirement and bonus_explanation_box and Global.tutorial_bonus_requirement_explanation_needed:
        #bonus_explanation_box.visible = true
        #Global.tutorial_bonus_requirement_explanation_needed = false

    # Celestial ("transcendent") explanation REMOVED from the reward screen: the tutorial fight
    # now teaches it directly on the Scout card in turn 3 ("its blue frame means Celestial: no
    # Power, no Dice, free to play"), so repeating it here is the player being told the same
    # thing twice. The panel node and its close handler are left in place, just never shown.

    # Same pattern as the two explanation boxes above, applied to Blessing cards - shown once,
    # the first time a Blessing shows up in a reward pick.
    if has_blessing_card and blessing_explanation_box and Global.tutorial_blessing_explanation_needed:
        blessing_explanation_box.visible = true
        Global.tutorial_blessing_explanation_needed = false


# Fire-and-forget coroutine (re-validates after its await, same as battle_reward.gd's
# _animate_reward_entrance): waits one frame so the containers have sorted this card
# (size/pivot/resting scale all invalid before that), then pops it in.
func _animate_card_entrance(menu: CardMenuUI, index: int, is_rare: bool) -> void:
    await get_tree().process_frame
    if not is_instance_valid(menu) or _picked:
        return
    var rest_scale: Vector2 = menu.scale
    _rest_scales[menu] = rest_scale
    menu.pivot_offset = menu.size / 2.0
    menu.scale = rest_scale * REVEAL_START_SCALE
    var tween := menu.create_tween()
    _intro_tweens.append(tween)
    tween.tween_interval(REVEAL_BASE_DELAY + index * REVEAL_STAGGER)
    tween.tween_callback(_play_reveal_sfx.bind(index))
    tween.tween_property(menu, "modulate:a", 1.0, REVEAL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(menu, "scale", rest_scale, REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if is_rare:
        tween.tween_callback(_play_rare_flash.bind(menu))


func _play_reveal_sfx(index: int) -> void:
    SFXPlayer.play(REVEAL_SFX, false, 1.0 + index * REVEAL_SFX_PITCH_STEP, REVEAL_SFX_VOLUME_DB)


# Golden overbright flash + rising motes behind the card. Motes are parented to Visuals
# (a plain Control - its children are NOT container-managed) with show_behind_parent, and
# tracked in _live_motes so the pick settle can clear them before the flight snapshot
# duplicates the Visuals subtree.
func _play_rare_flash(menu: CardMenuUI) -> void:
    if not is_instance_valid(menu) or _picked:
        return
    var visuals := menu.get_node("Visuals") as Control
    SFXPlayer.play(RARE_SFX, false, RARE_SFX_PITCH, RARE_SFX_VOLUME_DB)
    var flash := visuals.create_tween()
    _fx_tweens.append(flash)
    flash.tween_property(visuals, "modulate", RARE_FLASH_COLOR, RARE_FLASH_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    flash.tween_property(visuals, "modulate", Color.WHITE, RARE_FLASH_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _spawn_rare_motes(visuals)


func _spawn_rare_motes(visuals: Control) -> void:
    for i in RARE_MOTE_COUNT:
        var mote := TextureRect.new()
        mote.name = "RareMote%d" % i
        mote.texture = _get_mote_texture()
        mote.material = _get_mote_material()
        mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mote.show_behind_parent = true
        mote.stretch_mode = TextureRect.STRETCH_SCALE
        mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        var mote_size := randf_range(10.0, 22.0)
        mote.size = Vector2(mote_size, mote_size)
        mote.modulate = Color(RARE_MOTE_COLOR.r, RARE_MOTE_COLOR.g, RARE_MOTE_COLOR.b, 0.0)
        # Spawn OUTSIDE the card's footprint (side bands + above the top edge) - the card
        # body is opaque and the motes render behind it, so anything spawned inside the rect
        # is invisible for its whole rise (first version made exactly that mistake).
        var band := randf()
        var spawn := Vector2.ZERO
        if band < 0.35:
            spawn = Vector2(randf_range(-20.0, -6.0), randf_range(visuals.size.y * 0.15, visuals.size.y * 0.85))
        elif band < 0.7:
            spawn = Vector2(visuals.size.x + randf_range(6.0, 20.0), randf_range(visuals.size.y * 0.15, visuals.size.y * 0.85))
        else:
            spawn = Vector2(randf_range(10.0, visuals.size.x - 10.0), randf_range(-22.0, -4.0))
        mote.position = spawn - Vector2(mote_size / 2.0, mote_size / 2.0)
        visuals.add_child(mote)
        _live_motes.append(mote)
        var rise := randf_range(46.0, 84.0)
        var duration := randf_range(0.6, 0.95)
        var move := mote.create_tween()
        move.tween_property(mote, "position:y", mote.position.y - rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        var fade := mote.create_tween()
        fade.tween_property(mote, "modulate:a", randf_range(0.65, 0.9), duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        fade.tween_property(mote, "modulate:a", 0.0, duration * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        fade.tween_callback(mote.queue_free)


func _on_card_menu_clicked(event: InputEvent, card_menu: CardMenuUI, card: Card) -> void:
    if _picked:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _picked = true
        _settle_intro()
        _play_pick_beat(card_menu)
        var seq := create_tween()
        seq.tween_interval(PICK_HOLD)
        seq.tween_callback(_finish_pick.bind(card_menu, card))


# Clicking mid-reveal: kill every entrance/flash tween and snap all cards to their resting
# state first, so the pick animations start from a clean slate instead of fighting them.
func _settle_intro() -> void:
    for tween in _intro_tweens:
        if tween and tween.is_valid():
            tween.kill()
    _intro_tweens.clear()
    for tween in _fx_tweens:
        if tween and tween.is_valid():
            tween.kill()
    _fx_tweens.clear()
    for mote in _live_motes:
        if is_instance_valid(mote):
            mote.queue_free()
    _live_motes.clear()
    for menu in _card_menus:
        if not is_instance_valid(menu):
            continue
        menu.modulate = Color.WHITE
        menu.scale = _rest_scales.get(menu, Vector2.ONE)
        var visuals := menu.get_node("Visuals") as Control
        visuals.modulate = Color.WHITE


func _play_pick_beat(chosen: CardMenuUI) -> void:
    SFXPlayer.play(PICK_SFX, false, PICK_SFX_PITCH, PICK_SFX_VOLUME_DB)
    for menu in _card_menus:
        if not is_instance_valid(menu):
            continue
        var rest_scale: Vector2 = _rest_scales.get(menu, Vector2.ONE)
        menu.pivot_offset = menu.size / 2.0
        if menu == chosen:
            var punch := menu.create_tween()
            punch.tween_property(menu, "scale", rest_scale * PICK_PUNCH_SCALE, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
            punch.tween_property(menu, "scale", rest_scale * PICK_SETTLE_SCALE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            var visuals := menu.get_node("Visuals") as Control
            var flash := visuals.create_tween()
            flash.tween_property(visuals, "modulate", PICK_FLASH_COLOR, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
            flash.tween_property(visuals, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        else:
            var reject := menu.create_tween()
            reject.tween_property(menu, "modulate", REJECT_TINT, REJECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
            reject.parallel().tween_property(menu, "scale", rest_scale * REJECT_SCALE, REJECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _finish_pick(card_menu: CardMenuUI, card: Card) -> void:
    if is_instance_valid(card_menu):
        _launch_pick_flight(card_menu)
    card_reward_selected.emit(card)
    queue_free()


# Sends a static snapshot of the chosen card flying to the top-bar deck button. The snapshot
# lives on its own CanvasLayer under the tree root with tweens bound to ITSELF, so it survives
# this screen's queue_free (same ownership pattern as card_ui.gd's flight trail motes).
# duplicate(0) = no signals/groups/scripts copied - a pure display clone, nothing on it can
# call back into this (freed) screen.
func _launch_pick_flight(card_menu: CardMenuUI) -> void:
    var visuals := card_menu.get_node("Visuals") as Control
    var canvas_xform := visuals.get_global_transform_with_canvas()
    var start_scale := canvas_xform.get_scale()
    var start_center := canvas_xform * (visuals.size / 2.0)

    var layer := CanvasLayer.new()
    layer.layer = FLIGHT_LAYER
    get_tree().root.add_child(layer)

    var clone := visuals.duplicate(0) as Control
    _mute_input(clone)
    clone.pivot_offset = visuals.size / 2.0
    clone.scale = start_scale
    clone.position = start_center - clone.pivot_offset
    clone.modulate = Color.WHITE
    layer.add_child(clone)

    # The DeckButton lives in run.tscn's TopBar (a CanvasLayer, so both endpoints resolve in
    # screen space). Debug boots without the run scene just dissolve the snapshot in place.
    var deck_button := get_tree().root.find_child("DeckButton", true, false) as Control
    if deck_button == null:
        var dissolve := clone.create_tween()
        dissolve.tween_property(clone, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        dissolve.tween_callback(layer.queue_free)
        return

    var target_center := deck_button.get_global_transform_with_canvas() * (deck_button.size / 2.0)
    var fly := clone.create_tween()
    fly.tween_property(clone, "position", target_center - clone.pivot_offset, FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly.parallel().tween_property(clone, "scale", start_scale * FLIGHT_END_SCALE, FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fly.parallel().tween_property(clone, "rotation_degrees", FLIGHT_BANK_DEGREES, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    # Arrival callbacks are bound to the deck button / SFXPlayer autoload, never to this
    # screen - it is already freed by the time these fire.
    if deck_button.has_method("receive_punch"):
        fly.tween_callback(deck_button.receive_punch)
    fly.tween_callback(SFXPlayer.play.bind(FLIGHT_ARRIVE_SFX, false, FLIGHT_ARRIVE_PITCH, FLIGHT_ARRIVE_VOLUME_DB))
    fly.tween_callback(layer.queue_free)

    var fade := clone.create_tween()
    fade.tween_interval(FLIGHT_TIME - FLIGHT_FADE_TIME)
    fade.tween_property(clone, "modulate:a", 0.0, FLIGHT_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


static func _mute_input(node: Node) -> void:
    if node is Control:
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        _mute_input(child)


# Soft radial dot + additive material for the rare motes - same recipe as the power orbs /
# dice_infusion motes, cached as statics.
static func _get_mote_texture() -> GradientTexture2D:
    if _mote_texture:
        return _mote_texture
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    gradient.colors = PackedColorArray([
        Color(1.0, 1.0, 1.0, 0.95),
        Color(1.0, 1.0, 1.0, 0.4),
        Color(1.0, 1.0, 1.0, 0.0)])
    _mote_texture = GradientTexture2D.new()
    _mote_texture.gradient = gradient
    _mote_texture.width = 64
    _mote_texture.height = 64
    _mote_texture.fill = GradientTexture2D.FILL_RADIAL
    _mote_texture.fill_from = Vector2(0.5, 0.5)
    _mote_texture.fill_to = Vector2(0.5, 0.0)
    return _mote_texture


static func _get_mote_material() -> CanvasItemMaterial:
    if _mote_material:
        return _mote_material
    _mote_material = CanvasItemMaterial.new()
    _mote_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    return _mote_material


func _on_button_pressed() -> void:
    bonus_explanation_box.hide()


func _on_button_2_pressed() -> void:
    bonus_explanation_box_2.hide()


func _on_button_3_pressed() -> void:
    blessing_explanation_box.hide()
