class_name Card
extends Resource

enum Type {ATTACK, SKILL, BLESSING}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}
# NOT a drop-rarity axis despite the name - this is the "does playing this card reset your
# Power" mechanic flag (see hand.gd:296). Drop rarity lives in RarityTier/rarity_tier below;
# the two are fully independent (a support card can be Common, Uncommon, or Rare).
enum Rarity {NORMAL, SUPPORT}
enum RarityTier {COMMON, UNCOMMON, RARE}
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
@export var rarity_tier: RarityTier = RarityTier.COMMON
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
@export var upgraded: bool = false
@export var upgraded_version: Card


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


func can_be_upgraded() -> bool:
    return upgraded_version != null and not upgraded


# Whether this play should actually exhaust the card, as opposed to going to discard like a
# normal play. `exhausts` alone isn't enough for a gated card (e.g. a Blessing with Requirement
# MIN/EXACT/etc.): if the roll didn't meet the requirement, apply_effects() already silently
# no-ops (see meets_requirement() above), so exhausting on top of that would burn a permanent-
# effect card for literally nothing - worse than a normal miss, which at least still goes to
# discard and can be drawn/played again. Ungated cards (Requirement.NONE, the common case for
# most Blessings) are unaffected since meets_requirement() always returns true for them.
func should_exhaust() -> bool:
    return exhausts and meets_requirement()


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


# Applies the target enemy's own DMG_TAKEN modifier (Exposed being the main one today) on top
# of an already player-modified damage amount - mirrors exactly what actually happens at play
# time: apply_effects() applies the player's DMG_DEALT modifiers, then Enemy.take_damage()
# separately applies the target's own DMG_TAKEN modifiers via its own ModifierHandler. Dynamic
# descriptions only ever did the first half, so the damage preview undercounted against an
# Exposed (or any future DMG_TAKEN-buffed) enemy while the actual damage dealt was correct.
# `target` is whatever's currently being aimed at (see CardUI.targets / card_target_selector.gd)
# - null whenever nothing is targeted yet, in which case this is a no-op.
func apply_target_modifier(amount: int, target: Node) -> int:
    # Berserker infusion preview: while THIS card is the one socketed on an infused Red
    # die, mirror damage_effect.gd's +50% here so the socketed-card display and the
    # aiming preview show the number that will actually hit. Applied BEFORE the target's
    # DMG_TAKEN modifier - same order as the real flow (damage_effect boosts, then
    # Enemy.take_damage applies the target's own modifiers). Preview-only by
    # construction: this helper is never called from any apply_effects() (verified across
    # all 80 dynamic-description cards, 2026-07-10) - the REAL boost stays in
    # damage_effect.gd, so there is no double-count.
    if Global.charged_card_instance_id != 0 \
            and instance_id == Global.charged_card_instance_id \
            and Global.is_dice_infused("red"):
        amount = ceili(amount * 1.5)
    if target and is_instance_valid(target) and target.get("modifier_handler"):
        return target.modifier_handler.get_modified_value(amount, Modifier.Type.DMG_TAKEN)
    return amount


# Wraps every keyword from this card's `tags` (e.g. "Charge, Infused") that appears in `text`
# with a BBCode [color] tag - see KeywordColorizer for the keyword list/colors/regex logic
# (shared with Relic.get_colorized_description(), the other real consumer of this).
func get_colorized_description(text: String) -> String:
    return KeywordColorizer.colorize(text, tags)


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

    var particles = preload("res://scenes/card_ui/card_particles.tscn").instantiate()
    var target_array = targets if is_single_targeted() else _get_targets(targets)
    if target_array.size() > 0:
        target_array[0].get_parent().add_child(particles)
        particles.global_position = target_array[0].get_viewport().get_mouse_position()
        particles.play_effect(Global.roll_value, Global.dice_type)
    
    # Berserker infusion (Red act-2 infusion): the card socketed on the Red die deals 50%
    # more damage when its roll plays it. Global.playing_red_card is true for exactly that
    # play window (set when the Red roll is accepted in dice.gd, cleared right after the
    # play in both the instant path and the aim-then-release path), so scoping the boost
    # flag around apply_effects() keeps unrelated damage out of the window (e.g. House
    # Money's relic damage reacting to the same roll). damage_effect.gd applies the
    # actual multiplier, enemies only.
    var berserker_boost: bool = Global.playing_red_card and Global.is_dice_infused("red")
    if berserker_boost:
        Global.berserker_boost_active = true

    # Kaboom achievement: sum every point of damage enemies take during this one card
    # play (damage_effect.gd reports each hit while the window is open, so multi-hit
    # and AoE cards count as a single total).
    AchievementManager.begin_card_damage_window()

    if is_single_targeted():
        apply_effects(targets, modifiers)
    else:
        apply_effects(_get_targets(targets), modifiers)

    AchievementManager.end_card_damage_window()

    if berserker_boost:
        Global.berserker_boost_active = false

    # Bonus hit-stop for meeting a strict EXACT requirement - a "you nailed it" beat, on top
    # of whatever hit-stop the effect itself triggered (safe to overlap now that Shaker.hit_stop
    # is reference-counted). Deliberately a flat duration rather than scaled by damage: it's
    # sized to matter on a modest hit (e.g. Duo's 8 damage would only earn ~0.11s on its own)
    # without piling onto an already-huge hit (Doomsday's own damage-based hit-stop is already
    # bigger than this on its own, so the bonus just gets absorbed/ignored there - no double-
    # counting needed). Also fires on EXACT cards with no damage at all (e.g. Eruption), which
    # otherwise get zero hit-stop today. EXACT only for now, not MIN/MAX/MULTIPLE/EVEN/ODD.
    if requirement == Requirement.EXACT and meets_requirement():
        Shaker.hit_stop(0.16)


func apply_effects(_targets: Array[Node], modifiers: ModifierHandler) -> void:
    pass
    
