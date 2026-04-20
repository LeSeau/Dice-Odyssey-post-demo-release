class_name CardRewards
extends ColorRect

signal card_reward_selected(card: Card)

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

@export var rewards: Array[Card] : set = set_rewards

@onready var cards: HBoxContainer = %Cards
@onready var skip_card_reward: Button = $VBoxContainer/SkipCardReward
@onready var card_menu_ai: CardMenuUI = $VBoxContainer/Cards/CardMenuAI
@onready var card_menu_ai_2: CardMenuUI = $VBoxContainer/Cards/CardMenuAI2
@onready var card_menu_ai_3: CardMenuUI = $VBoxContainer/Cards/CardMenuAI3

@onready var bonus_explanation_box_2: Panel = $BonusExplanationBox2
@onready var bonus_explanation_box: Panel = $VBoxContainer/CanvasLayer/BonusExplanationBox

@onready var button: Button = $BonusExplanationBox/Button
@onready var button_2: Button = $BonusExplanationBox2/Button2


func _ready() -> void:
    clear_rewards()
    
    skip_card_reward.pressed.connect(
        func():
            card_reward_selected.emit(null)
            print("skipped card reward")
            queue_free()
    )
        
func clear_rewards() -> void:
    for card in cards.get_children():
        card.queue_free()
        bonus_explanation_box.visible = false
        
        
func set_rewards(new_cards: Array[Card]) -> void:
    rewards = new_cards
    
    if not is_node_ready():
        await ready
        
    clear_rewards()
    
    var has_bonus_requirement := false
    var has_transcendent_card := false
    for card: Card in rewards:
        var new_card := CARD_MENU_UI.instantiate() as CardMenuUI
        cards.add_child(new_card)
        new_card.card = card

        # 🔥 Make it bigger by scaling its visuals
        new_card.get_node("Visuals").scale = Vector2(1.5, 1.5)  # Adjust the factor as needed

        # Connect click
        new_card.get_node("Visuals").gui_input.connect(_on_card_menu_clicked.bind(new_card, card))
        print("Connected gui_input for card: ", card.name)
        
        
        # Check if this card has a bonus requirement
        if card.can_play_without_dice:
            has_transcendent_card = true
        if card.bonus_requirement != Card.Requirement.NONE:
            has_bonus_requirement = true
    
    # Show the explanation box if any card has a bonus requirement
    if has_bonus_requirement and bonus_explanation_box and Global.tutorial_bonus_requirement_explanation_needed:
        bonus_explanation_box.visible = true
        Global.tutorial_bonus_requirement_explanation_needed = false
        
    if has_transcendent_card and bonus_explanation_box_2 and Global.tutorial_transcendent_explanation_needed:
        bonus_explanation_box_2.visible = true
        Global.tutorial_transcendent_explanation_needed = false
        

    

func _on_card_menu_clicked(event: InputEvent, card_menu: CardMenuUI, card: Card) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        card_reward_selected.emit(card)
        print("drafted %s" % card.name)
        queue_free()    


func _on_button_pressed() -> void:
    bonus_explanation_box.hide()


func _on_button_2_pressed() -> void:
    bonus_explanation_box_2.hide()
