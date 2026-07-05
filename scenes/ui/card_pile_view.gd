class_name CardPileView
extends Control

const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")

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




func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_back_pressed()


# Both Global.removing_card/upgrading_card are only meant to be true while this view is open -
# clearing them here (not just on a successful remove/upgrade) prevents a stuck flag from
# leaking into unrelated CardMenuUI screens (shop, rewards) if the player backs out mid-action.
func _on_back_pressed() -> void:
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
        
    for card: Card in all_cards:
        var new_card := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
        cards.add_child(new_card)
        new_card.card = card
        
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
    if _card_pending_upgrade and card_pile:
        card_pile.replace_card(_card_pending_upgrade, _card_pending_upgrade.upgraded_version)
    _card_pending_upgrade = null
    Global.upgrading_card = false
    upgrade_confirm_panel.hide()
    hide()


func _on_cancel_upgrade_pressed() -> void:
    _card_pending_upgrade = null
    upgrade_confirm_panel.hide()
