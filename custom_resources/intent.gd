class_name Intent
extends Resource

@export var base_text: String
@export var icon: Texture
# Optional second icon rendered after the number - the STS2-style "rider" for combo intents
# (attack + debuff, block + buff...): two separate full-size glyphs side by side instead of
# one merged artwork. Null = single-icon intent, the second slot never enters the layout.
@export var icon2: Texture

var current_text: String
