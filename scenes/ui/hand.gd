class_name Hand
extends HBoxContainer

const CARD_UI_SCENE := preload("res://scenes/card_ui/card_ui.tscn")
@export var char_stats: CharacterStats
@export var player: Player

# Card fanning settings
@export var fan_radius: float = 20.0  # How much the cards fan out
@export var fan_degrees: float = 15.0  # Maximum angle for the fanning effect
@export var hover_lift: float = -20.0  # How much the card lifts when hovered
@export var hover_time: float = 0.15   # Animation time for hovering

# Sized so the WHOLE card clears the bottom of the screen, not by feel: cards sit at y~576 in
# the fan and stand 210px tall (222 once scaled), so anything less than ~85 leaves the card's
# lower edge cut off by the viewport - which is exactly what a step saying "look at this card"
# must not do (Julien: "we should be able to see the whole card easily"). An earlier -64/1.22
# pass was rejected as "weird", but that was a big POP; this is still a gentle held lift, just
# far enough up to be fully readable. Note the scale stays modest for the same reason.
# The above_hand text band in tutorial_overlay.gd is calibrated against this value - raising
# the lift further would need that band's bottom raised to match, and there is little room.
const TUTORIAL_LIFT := -92.0
const TUTORIAL_SCALE := Vector2(1.06, 1.06)

# The tutorial "locks" a card lifted. While locked, hover-in/out on that card re-asserts the
# lift instead of resetting to base - otherwise hovering it and moving away would drop it back
# down (the plain hover's mouse_exited reset). Cleared by clear_card_lift when the step ends.
var tutorial_locked_card: CardUI = null

# TutorialDirector's input gate, mirrored here. null = no gate (every normal fight); an Array
# of allowed card ids = only those cards may be picked up.
#
# It has to live in THIS file, not only in the director, because both places that decide a
# CardUI's `disabled` are here and both used to hand cards back interactive behind the gate's
# back:
#   * add_card() builds every CardUI fresh, so it arrives at the default disabled = false. The
#     turn-start deal takes ~1.25s (5 cards x HAND_DRAW_INTERVAL) and player_hand_drawn - the
#     only thing that re-applied the gate - fires at the very END, so a whole scripted turn's
#     hand was fully playable for over a second on every turn.
#   * _on_card_ui_reparent_requested() re-enabled unconditionally on the way back to BASE, so
#     one cancelled drag un-gated that card permanently.
# Either one lets an off-script card be played mid-step, which is what desynced the tutorial
# for the itch playtester who "just started clicking things": their Reinforce went out during
# the Low Blow step, and the step that later asked for Reinforce found it in the discard and
# disabled the entire hand, ROLL, every dice slot and End Turn at once - only "Skip Tutorial"
# was left clickable. Both paths now ask the gate instead of assuming.
var tutorial_card_gate = null

# Store original vertical Y positions (not X!)
var _original_positions: Dictionary = {}
var _original_z_indices: Dictionary = {}

func _ready() -> void:
    # In-hand passives (Global.in_hand) scan this node's children live - see Global's
    # IN_HAND_* consts for why it reads the tree instead of a mirrored set.
    add_to_group("hand")
    resized.connect(_update_card_positions)
    Events.fan_hand_requested.connect(_update_card_positions)
    Events.add_card_to_hand_requested.connect(_on_add_card_to_hand_requested)
    Events.hover_playable_cards.connect(_on_hover_playable_cards)
    
func tutorial_gate_allows(card_ui: CardUI) -> bool:
    if tutorial_card_gate == null:
        return true
    return card_ui.card != null and tutorial_card_gate.has(card_ui.card.id)


func add_card(card: Card) -> void:
    var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
    add_child(new_card_ui)
    new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
    new_card_ui.card = card
    new_card_ui.parent = self
    new_card_ui.char_stats = char_stats
    new_card_ui.player_modifiers = player.modifier_handler

    new_card_ui.mouse_entered.connect(_on_card_mouse_entered.bind(new_card_ui))
    new_card_ui.mouse_exited.connect(_on_card_mouse_exited.bind(new_card_ui))

    # Set AFTER .card is assigned (the gate matches on card.id) and before the card can take
    # any input, so a card dealt mid-step is never live for a frame. No-op outside the tutorial.
    new_card_ui.disabled = not tutorial_gate_allows(new_card_ui)

    new_card_ui.set_playable_visual(_get_glow_state(card))
    _play_draw_entrance(new_card_ui)
    call_deferred("_update_card_positions")


# Draw entrance: cards used to pop into the fan fully-formed in a single frame. Deliberately
# only touches `modulate` - the fan layout owns position/rotation (and re-stomps both on every
# subsequent card of the same deal), and scale/pivot are owned by the hover system, so an
# entrance on any of those either fights the layout or changes established hover behavior.
# An overbright materialize settling into the card's real look, plus the draw pile physically
# "dispensing" each card (receive_punch), reads as dealt without touching contested properties.
func _play_draw_entrance(card_ui: CardUI) -> void:
    # set_playable_visual above may have dimmed the card (most draws land before any roll) -
    # the entrance must settle into THAT look, not force full white over the dim state.
    var resting_modulate := card_ui.modulate
    card_ui.modulate = Color(resting_modulate.r, resting_modulate.g, resting_modulate.b, 0.0)
    # Tween owned by the card itself, not the Hand - if the card is freed mid-entrance the
    # tween dies with it instead of writing to a freed object.
    var entrance := card_ui.create_tween()
    entrance.tween_property(card_ui, "modulate", Color(1.55, 1.45, 1.15, 1.0), 0.09) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    entrance.tween_property(card_ui, "modulate", resting_modulate, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func discard_card(card: CardUI) -> void:
    if tutorial_locked_card == card:
        tutorial_locked_card = null
    if _original_positions.has(card):
        _original_positions.erase(card)
    # Sweep the card into the discard pile instead of deleting it in place (it used to just
    # vanish from the fan). fly_hand_discard reparents it to the ui_layer immediately, so
    # it stops counting as a hand child right away - the deferred fan update below and
    # player_handler's discard iteration both see it as already gone, same as queue_free did.
    card.fly_hand_discard()
    call_deferred("_update_card_positions")

func disable_hand() -> void:
    for card: CardUI in get_children():
        card.disabled = true

func _on_card_ui_reparent_requested(child: CardUI) -> void:
    child.disabled = true
    child.reparent(self)
    var new_index := clampi(child.original_index, 0, get_child_count())
    move_child.call_deferred(child, new_index)
    # Deliberately NOT an unconditional re-enable: a card coming home from a cancelled drag
    # must land back under whatever gate is in force, or the tutorial loses it for good.
    child.set_deferred("disabled", not tutorial_gate_allows(child))
    call_deferred("_update_card_positions")

func _update_card_positions() -> void:
    
    var card_count := get_child_count()
    if card_count == 0:
        return

    if card_count > 1:
        for i in range(card_count):
            var card := get_child(i) as CardUI
            if card:
                var progress := float(i) / float(card_count - 1)
                var angle := fan_degrees * (progress - 0.5)
                card.rotation_degrees = round(angle)

                var vertical_offset := -sin(progress * PI) * fan_radius
                card.position.y = round(vertical_offset)
                card.z_index = i*3
                _original_z_indices[card] = i * 3
                # Store only the Y position
                _original_positions[card] = Vector2(0, card.position.y)
                #card.scale = Vector2(1.1, 1.1)
    else:
        var card := get_child(0) as CardUI
        if card:
            card.rotation_degrees = 0
            card.position.y = 0
            _original_positions[card] = Vector2(0, 0)

    

func _on_card_mouse_entered(card: CardUI) -> void:
    if card.disabled or not _original_positions.has(card):
        return
    # Locked (tutorial) card keeps its bigger lift on hover rather than dropping to the plain
    # hover height - never falls below the tutorial lift while the step is active.
    if card == tutorial_locked_card:
        if Global.dragging_card == false:
            highlight_card_lift(card)
        return
    if Global.dragging_card == false:
        var tween := create_tween()
        tween.tween_property(card, "position:y",
            _original_positions[card].y + hover_lift, hover_time).set_ease(Tween.EASE_OUT)
        card.z_index = 50
        card.rotation_degrees = 0
        card.scale = Vector2(1.12, 1.12)

func _on_card_mouse_exited(card: CardUI) -> void:
    if not _original_positions.has(card):
        return
    # Locked (tutorial) card must not reset to base on hover-out - re-assert the lift instead,
    # unless it's mid-drag (the drag system owns its position then).
    if card == tutorial_locked_card:
        if Global.dragging_card == false:
            highlight_card_lift(card)
        return
    if Global.dragging_card == false:
        var tween := create_tween()
        tween.tween_property(card, "position:y",
            _original_positions[card].y, hover_time).set_ease(Tween.EASE_IN)
        card.z_index = _original_z_indices.get(card, 1)
        card.rotation_degrees = _get_card_fan_angle(card)
        card.scale = Vector2(1.0, 1.0)

# Tutorial card highlight: lift+de-rotate+scale the actual card node (the same visual the
# real hover produces) instead of drawing an external rectangle over it - a rectangle from
# get_global_rect() is axis-aligned and ignores the fan rotation applied above, so it never
# lines up with a fanned card's rotated silhouette. Deliberately does NOT reuse
# _on_card_mouse_entered: that early-returns on card.disabled, and the tutorial lifts a card
# in the same step that re-enables it (gate applied just after), so the card is still disabled
# at lift time - the hover path would silently no-op. This path ignores disabled on purpose.
func highlight_card_lift(card: CardUI) -> void:
    tutorial_locked_card = card
    # Fall back to the card's CURRENT y when the fan positions haven't been cached yet - without
    # this the lift silently no-ops (only the lock got set) whenever _original_positions was
    # empty at call time, which is exactly why the tutorial's Strike wasn't visibly lifting.
    var base_y: float = _original_positions[card].y if _original_positions.has(card) else card.position.y
    var tween := create_tween()
    tween.tween_property(card, "position:y",
        base_y + TUTORIAL_LIFT, hover_time).set_ease(Tween.EASE_OUT)
    card.z_index = 60
    card.rotation_degrees = 0
    card.scale = TUTORIAL_SCALE

func clear_card_lift(card: CardUI) -> void:
    if tutorial_locked_card == card:
        tutorial_locked_card = null
    if not _original_positions.has(card):
        return
    var tween := create_tween()
    tween.tween_property(card, "position:y",
        _original_positions[card].y, hover_time).set_ease(Tween.EASE_IN)
    card.z_index = _original_z_indices.get(card, 1)
    card.rotation_degrees = _get_card_fan_angle(card)
    card.scale = Vector2(1.0, 1.0)

func _on_add_card_to_hand_requested(card: Card) -> void:
    add_card(card)

# Get all cards in hand
func get_cards_in_hand() -> Array[CardUI]:
    var cards: Array[CardUI] = []
    for child in get_children():
        if child is CardUI:
            cards.append(child)
    return cards

# Get cards with specific requirements
func get_cards_with_requirement(req: Card.Requirement) -> Array[CardUI]:
    var cards: Array[CardUI] = []
    for child in get_children():
        if child is CardUI and child.card:
            if child.card.requirement == req:
                cards.append(child)
    return cards

# Get cards that have ANY requirement (not NONE)
func get_cards_with_any_requirement() -> Array[CardUI]:
    var cards: Array[CardUI] = []
    for child in get_children():
        if child is CardUI and child.card:
            if child.card.requirement != Card.Requirement.NONE:
                cards.append(child)
    return cards

# Get cards with specific requirement AND a specific number
func get_cards_with_requirement_and_number(req: Card.Requirement, num: int) -> Array[CardUI]:
    var cards: Array[CardUI] = []
    for child in get_children():
        if child is CardUI and child.card:
            if child.card.requirement == req and child.card.requirement_number == num:
                cards.append(child)
    return cards

# Check if hand has any cards with requirements
func has_cards_with_requirements() -> bool:
    for child in get_children():
        if child is CardUI and child.card:
            if child.card.requirement != Card.Requirement.NONE:
                return true
    return false

# Print all cards and their requirements (for debugging)
func debug_print_hand_requirements() -> void:
    print("=== Cards in Hand ===")
    for i in get_child_count():
        var card := get_child(i) as CardUI
        if card and card.card:
            print("Card %d: %s | Requirement: %s | Req Number: %d" % [
                i, 
                card.card.name, 
                Card.Requirement.keys()[card.card.requirement],
                card.card.requirement_number
            ])
            
# Check if a specific card's requirement is met
func check_card_requirement(card: Card) -> bool:
    if card.requirement == Card.Requirement.NONE:
        return true
    
    var roll = Global.roll_value
    
    match card.requirement:
        Card.Requirement.MAX:
            return roll <= card.requirement_number
        Card.Requirement.MIN:
            return roll >= card.requirement_number
        Card.Requirement.RED:
            return Global.dice_type == "red"
        Card.Requirement.MULTIPLE:
            if card.requirement_number == 0:
                return false
            return roll % card.requirement_number == 0
        Card.Requirement.EXACT:
            return roll == card.requirement_number
        Card.Requirement.EVEN:
            return roll % 2 == 0
        Card.Requirement.ODD:
            return roll % 2 == 1
        _:
            return true

# Get all cards in hand that meet their requirements
func get_playable_cards() -> Array[CardUI]:
    var playable: Array[CardUI] = []
    for child in get_children():
        if child is CardUI and child.card:
            if check_card_requirement(child.card):
                playable.append(child)
    return playable

# Get all cards that DON'T meet their requirements
func get_unplayable_cards() -> Array[CardUI]:
    var unplayable: Array[CardUI] = []
    for child in get_children():
        if child is CardUI and child.card:
            if not check_card_requirement(child.card):
                unplayable.append(child)
    return unplayable

# Check if a specific card UI is playable
func is_card_playable(card_ui: CardUI) -> bool:
    if not card_ui or not card_ui.card:
        return false
    return check_card_requirement(card_ui.card)
    
func _on_hover_playable_cards() -> void:
    for child in get_children():
        if child is CardUI and child.card:
            var card_ui := child as CardUI
            card_ui.set_playable_visual(_get_glow_state(card_ui.card))


# ---------------------------------------------------------------------------
# "You can still play something" flash (2026-08-15, STS2 audit 1.6)
#
# Fired when the player hovers End Turn. The reference does this and it's a genuinely
# great teaching beat: the button answers "why would I NOT end my turn?" at the exact
# moment the player considers it, instead of letting them discard a playable hand and
# only find out later. Our End Turn nudge already handles the opposite case (pulsing gold
# when nothing is left to do) - this is the other half of the same conversation.
#
# Deliberately modulate-ONLY. The fan owns position and rotation (and re-stomps both on
# every fan_hand_requested), and scale/pivot are owned by the hover system - an effect on
# any of those either gets erased or silently changes established hover behaviour. This is
# the same constraint the draw entrance ran into, and the same solution.
# ---------------------------------------------------------------------------
const PLAYABLE_FLASH_COLOR := Color(1.7, 1.62, 1.25, 1.0)
const PLAYABLE_FLASH_IN := 0.08
const PLAYABLE_FLASH_OUT := 0.3
const PLAYABLE_FLASH_STAGGER := 0.035

# card -> the modulate it must return to. Needed because a second flash landing mid-flash
# would otherwise capture the BRIGHTENED value as "resting" and cook it in permanently -
# the same restore-to-a-live-reading trap that turned the Power number white in July.
var _playable_flash_resting: Dictionary = {}
var _playable_flash_tweens: Dictionary = {}


func flash_playable_cards() -> void:
    _reset_playable_flashes()
    var i := 0
    for child in get_children():
        if not (child is CardUI):
            continue
        var card_ui := child as CardUI
        if card_ui.card == null or card_ui.disabled:
            continue
        # current_glow_state is already maintained by set_playable_visual, so this asks the
        # exact same question the card's own border is answering - the two can never
        # disagree about what "playable" means.
        if card_ui.current_glow_state != CardUI.PlayableGlow.HOT \
                and card_ui.current_glow_state != CardUI.PlayableGlow.AVAILABLE:
            continue
        var resting := card_ui.modulate
        _playable_flash_resting[card_ui] = resting
        var flash := card_ui.create_tween()
        _playable_flash_tweens[card_ui] = flash
        flash.tween_interval(PLAYABLE_FLASH_STAGGER * i)
        flash.tween_property(card_ui, "modulate", PLAYABLE_FLASH_COLOR, PLAYABLE_FLASH_IN) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        flash.tween_property(card_ui, "modulate", resting, PLAYABLE_FLASH_OUT) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        i += 1


func _reset_playable_flashes() -> void:
    for card_ui: Variant in _playable_flash_tweens.keys():
        var tween: Tween = _playable_flash_tweens[card_ui]
        if tween and tween.is_valid():
            tween.kill()
        if is_instance_valid(card_ui) and _playable_flash_resting.has(card_ui):
            card_ui.modulate = _playable_flash_resting[card_ui]
    _playable_flash_tweens.clear()
    _playable_flash_resting.clear()

func _get_glow_state(card: Card) -> CardUI.PlayableGlow:
    # Hex before Celestial. Junk USED to be Celestial, so it fell straight into the HOT
    # branch below and an enemy plant rendered as the single brightest card in the hand -
    # pulsing border in the active dice colour, the game premium signal. NEUTRAL rather than
    # NONE because NONE dims, and dim is the "no card can do anything right now" signal, which
    # would over-state it: a Hex is always binnable, it just is not always binnable THIS
    # instant. NEUTRAL is full brightness with no glow, so the card own ash chrome talks.
    # 2026-09-02: Slander is no longer Celestial (binning it costs a roll and your bank), so
    # this branch is what keeps a Hex from dimming before your first roll of the turn. The
    # drag refusal already says "you need Power" at the moment it matters.
    if card.type == Card.Type.HEX:
        return CardUI.PlayableGlow.NEUTRAL
    if card.can_play_without_dice:
        return CardUI.PlayableGlow.HOT
    if Global.ink_active:
        return CardUI.PlayableGlow.NEUTRAL
    if Global.dice_type == "red":
        if Global.red_dice_current_amount <= 0:
            return CardUI.PlayableGlow.NONE
        # Red commits the card before rolling, so only requirements that are
        # already known to be true right now (not dependent on the upcoming
        # roll) can be shown as a sure thing. Support cards (power
        # manipulation, e.g. Reinforce) are excluded even when their
        # requirement qualifies.
        if card.rarity != Card.Rarity.SUPPORT:
            if card.requirement == Card.Requirement.RED or card.requirement == Card.Requirement.MAX:
                return CardUI.PlayableGlow.HOT
            if card.requirement == Card.Requirement.NONE:
                return CardUI.PlayableGlow.AVAILABLE
        return CardUI.PlayableGlow.NONE
    # roll_value <= 0 alone would wrongly dim a card that's actually playable right now -
    # has_active_roll() catches the "rolled and landed on Evil's crack face (0)" case, which
    # is still a real roll, just an unlucky one (see card_released_state.gd's matching gate).
    if Global.roll_value <= 0 and not card.has_active_roll():
        return CardUI.PlayableGlow.NONE
    if card.requirement == Card.Requirement.NONE:
        return CardUI.PlayableGlow.AVAILABLE
    if check_card_requirement(card):
        return CardUI.PlayableGlow.HOT
    return CardUI.PlayableGlow.NONE

func _get_card_fan_angle(card: CardUI) -> float:
    var card_count := get_child_count()
    if card_count <= 1:
        return 0.0
    var i := card.get_index()
    var progress := float(i) / float(card_count - 1)
    return fan_degrees * (progress - 0.5)
