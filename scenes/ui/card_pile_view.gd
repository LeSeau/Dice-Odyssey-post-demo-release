class_name CardPileView
extends Control

const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")
# Same "cling" sound Reinforce/mech-dice-adjustment already use for a metal/forge feel.
const UPGRADE_SOUND := preload("res://sounds/blacksmithsound.wav")

# --- Inspect (right-click) -----------------------------------------------------------------
# Same overlay the reward picker and the card shop use: right-click any card in the grid for a
# magnified view with an upgrade preview toggle, paging through the whole pile. Useful in every
# mode this screen has - browsing the deck, choosing what to remove, and especially choosing
# what to UPGRADE, where "what does this actually become" is the entire question being asked.
const CARD_INSPECT_OVERLAY := preload("res://scenes/ui/card_inspect_overlay.gd")
const INSPECT_HINT_TEXT := "Right-click a card to preview its upgrade"
# Root is an unscaled full-rect Control, so these are screen pixels. The card grid's
# MarginContainer stops at y670 (margin_bottom 50) and the Back button lives at the TOP right,
# so the bottom strip is free - debug_card_inspect.gd asserts the rects stay disjoint.
const INSPECT_HINT_FONT_SIZE := 18
const INSPECT_HINT_ALPHA := 0.6
const INSPECT_HINT_BOTTOM_MARGIN := 14.0
const INSPECT_HINT_HEIGHT := 24.0

# Display order of the grid, so paging in the overlay matches what you are looking at.
var _displayed_cards: Array[Card] = []
var _inspect_overlay: Node = null
var _inspect_hint: Label = null

@export var card_pile: CardPile

@onready var title: Label = %Title
@onready var cards: GridContainer = %Cards
@onready var back_button: Button = %BackButton
@onready var upgrade_confirm_panel: Control = %UpgradeConfirmPanel
@onready var before_card: CardMenuUI = %BeforeCard
@onready var after_card: CardMenuUI = %AfterCard
@onready var confirm_upgrade_button: Button = %ConfirmUpgradeButton
@onready var cancel_upgrade_button: Button = %CancelUpgradeButton

var _card_pending_upgrade: Card


func _ready() -> void:
    # BackButton.pressed is already wired to _on_back_button_pressed in the .tscn, which
    # delegates to _on_back_pressed() below - not reconnected here to avoid firing twice.
    confirm_upgrade_button.pressed.connect(_on_confirm_upgrade_pressed)
    cancel_upgrade_button.pressed.connect(_on_cancel_upgrade_pressed)
    Events.card_upgrade_requested.connect(_on_card_upgrade_requested)

    before_card.interactive = false
    after_card.interactive = false
    before_card.disable_hover_tooltip = true
    after_card.disable_hover_tooltip = true

    for card: Node in cards.get_children():
        card.queue_free()

    _build_inspect_hint()


func _build_inspect_hint() -> void:
    var hint := CARD_INSPECT_OVERLAY.make_hint_label(
        INSPECT_HINT_TEXT, INSPECT_HINT_FONT_SIZE, INSPECT_HINT_ALPHA)
    hint.name = "InspectHint"
    hint.anchor_left = 0.0
    hint.anchor_right = 1.0
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_top = -(INSPECT_HINT_BOTTOM_MARGIN + INSPECT_HINT_HEIGHT)
    hint.offset_bottom = -INSPECT_HINT_BOTTOM_MARGIN
    add_child(hint)
    _inspect_hint = hint


func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        _open_inspect(card_index)


func _open_inspect(card_index: int) -> void:
    if _inspect_overlay != null or _displayed_cards.is_empty():
        return
    # The upgrade confirm dialog is this screen's OWN modal and renders inside this Control,
    # i.e. underneath the overlay's CanvasLayer 99 - opening on top of it would hide the very
    # thing waiting on an answer. Wait until it is dismissed instead.
    if upgrade_confirm_panel and upgrade_confirm_panel.visible:
        return
    var overlay: Node = CARD_INSPECT_OVERLAY.new()
    overlay.closed.connect(_on_inspect_closed)
    add_child(overlay)
    overlay.setup(_displayed_cards, card_index)
    _inspect_overlay = overlay
    _inspect_hint.hide()


func _on_inspect_closed() -> void:
    _inspect_overlay = null
    _inspect_hint.show()


# A CanvasLayer child IGNORES hide() on its Control parent (the documented trap that left
# MapBackground painted behind every screen for months). This view hides rather than frees
# itself, so the overlay has to be torn down by hand on every exit path - otherwise it would
# stay painted over the campfire, or over the battle it was opened from.
func _dismiss_inspect() -> void:
    if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
        _inspect_overlay.queue_free()
    _inspect_overlay = null
    if _inspect_hint:
        _inspect_hint.show()


func _input(event: InputEvent) -> void:
    # Only react while actually open, and consume the event so a single Esc press
    # closes just this view instead of ALSO reaching the pause menu's
    # _unhandled_input underneath (one close per press). The visible guard also
    # stops hidden pile-view instances (battle has three) from silently swallowing
    # every Esc pressed anywhere.
    if not visible:
        return
    # While the overlay is up it owns Esc: it closes itself and marks the event handled. This
    # guard makes that independent of _input dispatch order rather than relying on it.
    if _inspect_overlay != null:
        return
    if event.is_action_pressed("ui_cancel"):
        _on_back_pressed()
        get_viewport().set_input_as_handled()


# Both Global.removing_card/upgrading_card are only meant to be true while this view is open -
# clearing them here (not just on a successful remove/upgrade) prevents a stuck flag from
# leaking into unrelated CardMenuUI screens (shop, rewards) if the player backs out mid-action.
func _on_back_pressed() -> void:
    _dismiss_inspect()
    Global.removing_card = false
    Global.upgrading_card = false
    upgrade_confirm_panel.hide()
    _card_pending_upgrade = null
    hide()

func show_current_view(new_title: String, randomized: bool = false) -> void:
    for card: Node in cards.get_children():
        card.queue_free()
        
    title.text = new_title
    _update_view.call_deferred(randomized)
    
        
func _update_view(randomized: bool) -> void:
    print("updating view")
    if not card_pile:
        return
        
    var all_cards := card_pile.cards.duplicate()
    if randomized:
        all_cards.shuffle()
        
    _displayed_cards.clear()
    for card: Card in all_cards:
        var new_card := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
        cards.add_child(new_card)
        new_card.card = card
        # Bind the INDEX, not the Card: a deck can legitimately hold the same Card resource
        # more than once, and a find() would then always page from the first copy.
        new_card.get_node("Visuals").gui_input.connect(
            _on_card_gui_input.bind(_displayed_cards.size()))
        _displayed_cards.append(card)
        
    show()
        


func _on_back_button_pressed() -> void:
    _on_back_pressed()


func _on_card_upgrade_requested(card: Card) -> void:
    if not card.can_be_upgraded():
        return
    _card_pending_upgrade = card
    before_card.card = card
    after_card.card = card.upgraded_version
    upgrade_confirm_panel.show()


func _on_confirm_upgrade_pressed() -> void:
    _dismiss_inspect()
    if _card_pending_upgrade and card_pile:
        card_pile.replace_card(_card_pending_upgrade, _card_pending_upgrade.upgraded_version)
        SFXPlayer.play(UPGRADE_SOUND)
    _card_pending_upgrade = null
    Global.upgrading_card = false
    upgrade_confirm_panel.hide()
    hide()
    # Upgrading is only ever reachable from the campfire today (same as Rest, which also
    # exits via this signal) - mirror that so you can't linger and Rest afterward too.
    Events.campfire_exited.emit()


func _on_cancel_upgrade_pressed() -> void:
    _card_pending_upgrade = null
    upgrade_confirm_panel.hide()
