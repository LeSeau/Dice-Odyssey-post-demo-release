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

# Store original vertical Y positions (not X!)
var _original_positions: Dictionary = {}

func _ready() -> void:
    resized.connect(_update_card_positions)
    Events.fan_hand_requested.connect(_update_card_positions)
    Events.add_card_to_hand_requested.connect(_on_add_card_to_hand_requested)
    Events.hover_playable_cards.connect(_on_hover_playable_cards)
    
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

    call_deferred("_update_card_positions")

func discard_card(card: CardUI) -> void:
    if _original_positions.has(card):
        _original_positions.erase(card)
    card.queue_free()
    call_deferred("_update_card_positions")

func disable_hand() -> void:
    for card: CardUI in get_children():
        card.disabled = true

func _on_card_ui_reparent_requested(child: CardUI) -> void:
    child.disabled = true
    child.reparent(self)
    var new_index := clampi(child.original_index, 0, get_child_count())
    move_child.call_deferred(child, new_index)
    child.set_deferred("disabled", false)
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
    if Global.dragging_card == false:
        var tween := create_tween()
        tween.tween_property(card, "position:y",
            _original_positions[card].y, hover_time).set_ease(Tween.EASE_IN)
        card.z_index = 1
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
    # Optional: Keep debug for testing
    # debug_print_hand_requirements()
    
    var playable = get_playable_cards()
    var unplayable = get_unplayable_cards()
    
    # Highlight playable cards (full opacity)
    for card in playable:
        card.set_playable_visual(true)
    
    # Dim unplayable cards (reduced opacity)
    for card in unplayable:
        card.set_playable_visual(false)

func _get_card_fan_angle(card: CardUI) -> float:
    var card_count := get_child_count()
    if card_count <= 1:
        return 0.0
    var i := card.get_index()
    var progress := float(i) / float(card_count - 1)
    return fan_degrees * (progress - 0.5)
