class_name RewardButton
extends Button

@export var reward_icon: Texture : set = set_reward_icon
@export var reward_text: String : set = set_reward_text 

@onready var custom_icon: TextureRect = %CustomIcon
@onready var custom_text: Label = %CustomText

    
func set_reward_icon(new_icon: Texture) -> void:
    reward_icon = new_icon
    
    if not is_node_ready():
        await ready
        
    custom_icon.texture = reward_icon

func set_reward_text(new_text: String) -> void:
    reward_text = new_text

    if not is_node_ready():
        await ready

    custom_text.text = reward_text

# Kept for the pressed connection in reward_button.tscn. The row no longer frees itself: the
# reward screen decides when it goes (battle_reward.gd). A claimed row folds away, and a card
# row stays when its picker is skipped (reward_flow.gd, idea 7).
func _on_pressed() -> void:
    pass
