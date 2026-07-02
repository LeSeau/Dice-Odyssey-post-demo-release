class_name Card
extends Resource

enum Type {ATTACK, SKILL, RITE}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}
enum Rarity {NORMAL, SUPPORT}
enum Requirement {NONE, MIN, MAX, EVEN, ODD, RED, MULTIPLE, EXACT, PANDORA}

const RARITY_COLORS := {
    Card.Rarity.NORMAL: Color.GRAY, 
    Card.Rarity.SUPPORT: Color.GOLD
}

@export_group("Card Attributes")
@export var id: String
@export var name: String
@export var type: Type
@export var target: Target
@export var description: String
@export var rarity: Rarity
@export var red_only: bool
@export var can_play_without_dice: bool
@export var requirement: Requirement
@export var requirement_number: int
@export var exhausts: bool = false
@export var bonus_requirement: Requirement 
@export var bonus_requirement_number: int
@export var bonus_description_icon: Texture
@export var bonus_description_text: String
@export var tags: String


@export_group("Card Visuals")
@export var icon: Texture
@export_multiline var tooltip_text: String
@export var sound: AudioStream

var instance_id: int = 0

func _init():
    # Generate a unique ID when the card is created
    instance_id = randi()


func is_single_targeted() -> bool:
    return target == Target.SINGLE_ENEMY


# Global.roll_value == 0 is ambiguous: it's both the reset/no-roll-yet state
# AND a legitimate outcome of rolling a 0 face (evil dice). roll_history is
# cleared on every reset path and appended to on every real roll, so
# emptiness reliably distinguishes "haven't rolled since last reset" from
# "rolled and got exactly 0" — use this before resolving "X" in descriptions.
func has_active_roll() -> bool:
    return not Global.roll_history.is_empty()


# While inked, the dice UI covers the resolved power number with an ink
# splash (see scenes/dices/dice.gd _on_put_ink_on_dice) — the player genuinely
# can't read their current power, so dynamic descriptions shouldn't leak the
# resolved damage number either.
func is_inked() -> bool:
    return Global.ink_active


# Whether the card's own primary requirement (the MIN/MAX/EXACT/etc. ribbon badge on the
# card face) is currently satisfied by the active roll. `card.requirement` is otherwise
# purely cosmetic (badge text + tooltip) - nothing actually blocks playing a card that fails
# it, its apply_effects() just silently no-ops - so this is the one place that gives the enum
# real meaning. Dynamic descriptions use this to avoid resolving to a live number computed
# from a roll that wouldn't actually trigger the effect (e.g. showing "Deal 40 damage" on a
# Max 12 card at 20 Power, when the card would do nothing if played right now).
func meets_requirement() -> bool:
    match requirement:
        Requirement.NONE:
            return true
        Requirement.MIN:
            return Global.roll_value >= requirement_number
        Requirement.MAX:
            return Global.roll_value <= requirement_number
        Requirement.EVEN:
            return int(Global.roll_value) % 2 == 0
        Requirement.ODD:
            return int(Global.roll_value) % 2 == 1
        Requirement.RED:
            return Global.dice_type == "red"
        Requirement.MULTIPLE:
            return requirement_number != 0 and int(Global.roll_value) % requirement_number == 0
        Requirement.EXACT:
            return Global.roll_value == requirement_number
        _:
            return true


func _get_targets(targets: Array[Node]) -> Array[Node]:
    if not targets:
        return []
        
    var tree := targets[0].get_tree()
    
    match target:
        Target.SELF:
            return tree.get_nodes_in_group("player")
        Target.ALL_ENEMIES:
            return tree.get_nodes_in_group("enemies")
        Target.EVERYONE:
            return tree.get_nodes_in_group("player") + tree.get_nodes_in_group("enemies")
        _:
            return []


func play(targets: Array[Node], char_stats: CharacterStats, modifiers: ModifierHandler) -> void:

    Global.cards_played_this_turn+=1
    Events.card_played.emit(self)
    Events.check_ink_status.emit()
    if Global.tutorial_block == true && Global.tutorial_on:
        Events.tutorial_step_requested.emit(5)
        Global.tutorial_block = false
    if Global.tutorial_low_blow == true:
        Events.tutorial_step_requested.emit(8)
        Global.tutorial_low_blow = false
    if Global.tutorial_red_attack == true:
        Events.tutorial_step_requested.emit(11)
        Global.tutorial_red_attack = false
    if Global.tutorial_recombobulate == true:
        Events.tutorial_step_requested.emit(15)
        Global.tutorial_recombobulate = false

    
    var particles = preload("res://scenes/card_ui/card_particles.tscn").instantiate()
    var target_array = targets if is_single_targeted() else _get_targets(targets)
    if target_array.size() > 0:
        target_array[0].get_parent().add_child(particles)
        particles.global_position = target_array[0].get_viewport().get_mouse_position()
        particles.play_effect(Global.roll_value, Global.dice_type)
    
    if is_single_targeted():
        apply_effects(targets, modifiers)
    else:
        apply_effects(_get_targets(targets), modifiers)


func apply_effects(_targets: Array[Node], modifiers: ModifierHandler) -> void:
    pass
    
