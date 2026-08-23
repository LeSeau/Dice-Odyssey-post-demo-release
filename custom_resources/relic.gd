class_name Relic
extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}

# How often a relic is offered. Deliberately SEPARATE from `type` (which is a lifecycle hook)
# and from `shop_only` (which is availability): a shop-exclusive relic still needs a power
# level and a price, so folding "Shop" in here as a fourth rarity - the way Slay the Spire
# does - would conflate two independent questions.
# COMMON is the enum default, so only Uncommon/Rare relics need a line in their .tres.
enum RarityTier {COMMON, UNCOMMON, RARE}

@export var relic_name: String
@export var id: String
@export var type: Type
@export var rarity_tier: RarityTier = RarityTier.COMMON
# Never offered by treasure, elites or events - only sold in the shop. For relics that are
# DEAD without a specific die you own (Giant's Signet needs Giant dice), a chest would be a
# wasted reward, whereas a shelf you only buy from if it fits the dice you already have.
# Note this is about the PAYOFF needing the type: relics that GRANT an exotic die (Volcanic
# Rock, Trick Scale, Obsidian Scale) work for everyone and stay in the normal pool.
@export var shop_only: bool = false
@export var has_counter: bool = false
@export var counter: int
@export var starter_relic: bool = false
@export var icon: Texture
@export_multiline var tooltip: String
@export var tags: String


func initialize_relic(_owner: RelicUI) -> void:
    pass
    
func activate_relic(_owner: RelicUI) -> void:
    pass
    
    
#this method should be implemnted by event-based relics
#which connect to the event bus to make sure that they are
#disconnected when a relic gets removed

func deactivate_relic(_owner: RelicUI) -> void:
    pass 

func get_tooltip() -> String:
    return tooltip


# Wraps every keyword from this relic's `tags` (e.g. "Refuel, Strength") that appears in `text`
# with a BBCode [color] tag - see KeywordColorizer for the keyword list/colors/regex logic
# (shared with Card.get_colorized_description()).
func get_colorized_description(text: String, glyph_px: int = 16) -> String:
    return KeywordColorizer.colorize(text, tags, glyph_px)


func can_appear_as_reward(character: CharacterStats) -> bool:
    if starter_relic:
        return false
    return true
