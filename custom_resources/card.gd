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


# Sources that waive a card's requirement outright, letting it fire on a roll its badge
# would normally refuse. Add new bypassers (a status, an infused dice, a relic) HERE and
# every card honours them at once - that's the whole point of routing gates through
# meets_requirement() rather than hardcoding thresholds per script.
#
# Note this only waives the GATE, never the magnitude: a waived Max 3 card played at 12
# still computes off the real 12 (so Low Blow's roll*3 pays out 36). That's deliberate -
# breaking the caps is what a bypasser is for.
func _requirement_bypassed() -> bool:
    # Prayer Beads: "Blessings can be cast on any roll." Scoped to BLESSING because that's
    # exactly what the relic's tooltip promises, and it matches the behaviour of the 30
    # hand-written `or Global.blessing_cast_any_roll` checks this replaced (all Type.BLESSING).
    if type == Type.BLESSING and Global.blessing_cast_any_roll:
        return true
    return false


# Whether the card's own primary requirement (the MIN/MAX/EXACT/etc. ribbon badge on the
# card face) is currently satisfied. This is the single funnel every gate runs through:
# apply_effects() gates on it, should_exhaust() gates on it, and dynamic descriptions use it
# to avoid resolving to a live number computed from a roll that wouldn't actually trigger the
# effect (e.g. showing "Deal 40 damage" on a Max 12 card at 20 Power).
#
# Cards used to hardcode their own threshold (`if Global.roll_value >= 6`) instead. That's how
# Prayer Beads ended up pasted into 30 scripts while should_exhaust() never learned about it:
# a bypassed Blessing fired its effect, then failed meets_requirement(), so it landed in the
# discard pile instead of exhausting and could be redrawn and recast for the rest of the fight.
# One funnel means the gate, the exhaust decision and the preview text can no longer disagree.
func meets_requirement() -> bool:
    if requirement == Requirement.NONE:
        return true
    if _requirement_bypassed():
        return true
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


# Would playing this card RIGHT NOW do literally nothing? Drives the pick-up refusal in
# card_clicked_state.gd. Note this mostly makes EXISTING refusals audible rather than adding
# new ones: card_released_state.gd already declines to play a red_only card on the wrong dice,
# and any non-Celestial card before the first roll, silently bouncing both back to hand.
#
# Deliberately NOT the same question as hand.gd::_get_glow_state(). On the Red die most cards
# render dimmed because we cannot promise the upcoming roll will satisfy them - yet they are
# perfectly legal to socket, and committing before the roll is the entire point of Red. That
# dim means "no guarantee"; this means "no effect". Conflating the two would delete the gamble.
func would_no_op_now() -> bool:
    # Celestials never consult a roll at all.
    if can_play_without_dice:
        return false
    # Inked: the power number is hidden behind the splash, so refusing (or allowing) would
    # leak whether the concealed roll meets the requirement. Inked turns are gambles by design.
    if is_inked():
        return false
    # Already enforced in card_released_state.gd - the play is skipped, card returns to hand.
    if red_only and Global.dice_type != "red":
        return true
    if Global.dice_type == "red":
        # Socketing judges the requirement against a roll that has not happened yet, so it can
        # never be pre-judged. The one genuinely dead case is having no Red die left to roll.
        return Global.red_dice_current_amount <= 0
    # Nothing rolled yet. has_active_roll() rather than roll_value alone so Evil's crack face
    # (a real roll that resolved to 0) still counts - the same gate the play path and the hand
    # dimming both already use.
    if Global.roll_value <= 0 and not has_active_roll():
        return true
    return not meets_requirement()


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
    if Global.charged_card_instance_ids.has(instance_id) \
            and Global.is_dice_infused("red"):
        amount = ceili(amount * 1.5)
    if target and is_instance_valid(target) and target.get("modifier_handler"):
        return target.modifier_handler.get_modified_value(amount, Modifier.Type.DMG_TAKEN)
    return amount


# Wraps every keyword from this card's `tags` (e.g. "Charge, Infused") that appears in `text`
# with a BBCode [color] tag - see KeywordColorizer for the keyword list/colors/regex logic
# (shared with Relic.get_colorized_description(), the other real consumer of this).
func get_colorized_description(text: String, glyph_px: int = 16) -> String:
    return KeywordColorizer.colorize(text, tags, glyph_px)


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
    Global.run_stat_cards_played += 1
    Events.card_played.emit(self)
    Events.check_ink_status.emit()

    # ATTACK impacts are carried by the directional slash smear now (enemy.gd::
    # _spawn_hit_smear) - the radial burst on top read as generic magic and buried the
    # slash (Julien, 2026-08). Non-attack cards keep the burst: block/buff resolving on
    # a body still wants its "magic happened here" bloom, and there's no slash there.
    if type != Type.ATTACK:
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


# Face-value pools per dice type, shared by the thrown-dice cards (Meteor, Fastball, Cursed
# Toss, Pixie Volley, Dice Avalanche...). Same table as all_in.gd::DISPLAY_FACE_VALUES - the
# rolled value both drives the damage AND picks the face texture in the flight visual
# (dice.gd::_spawn_thrown_dice), so what the player sees land is exactly what hits.
const DICE_FACE_VALUES := {
    "blue": [1, 2, 3, 4, 5, 6], "red": [1, 2, 3, 4, 5, 6],
    "magma": [1, 2, 3, 4, 5, 6], "mech": [1, 2, 3, 4, 5, 6],
    "giant": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "evil": [0, 6, 6, 6],
    "even": [2, 4, 6, 8],
    "odd": [1, 3, 5, 7],
    "green": [1, 2, 3],
}


# Faces a conjured/thrown die of this type can land on. An infused type uses its infusion's
# face set - a thrown "Evil Dice" is YOUR Evil Dice, so Repented throws 6/6/6 and a Bulky
# Giant throws 7-12 (Julien, 2026-07-23). Safe visually: overrides are always a subset of
# faces the real die already displays, so every value has its face texture. Infusion ROLL
# effects (Gnome/Octet/Bulwark/Arcane) deliberately do NOT fire on thrown dice for now.
static func thrown_faces_for(dice_type: String) -> Array:
    return Global.current_face_values(dice_type)


# Where a thrown die visually smashes into this target - the torso center, NOT the enemy
# root (enemy.tscn bakes the Sprite2D at local x=124, so the root sits ~124px left of the
# body; same baseline as the name-label centering fix). Single source shared by dice.gd
# (where the die icon lands) and the damage side (where the popup spawns), so the number
# always pops off the exact spot the die just hit.
static func thrown_impact_pos(target: Node) -> Vector2:
    if target is Node2D:
        var sprite = target.get("sprite_2d")
        if sprite is Sprite2D and is_instance_valid(sprite):
            return (sprite as Sprite2D).global_position
        return (target as Node2D).global_position + Vector2(0.0, -30.0)
    return Vector2.ZERO


# Lands a thrown die's damage when its flight visual arrives (schedule with
# Global.DICE_THROW_FLIGHT_TIME to match the Events.dice_thrown animation). Deliberately
# raw damage - the die deals ITS roll, not a Strength-modified hit (the target's own
# DMG_TAKEN modifiers like Exposed still apply inside take_damage). If the target died
# mid-flight the die bounces to a random living enemy; if the fight is over, it lands on
# nothing.
func _land_thrown_die(tree: SceneTree, target: Node, damage: int, delay: float, hit_sound: AudioStream, dice_type: String, value: int) -> void:
    var timer := tree.create_timer(delay, false)
    timer.timeout.connect(_on_thrown_die_landed.bind(tree, target, damage, hit_sound, dice_type, value))


func _on_thrown_die_landed(tree: SceneTree, target: Node, damage: int, hit_sound: AudioStream, dice_type: String, value: int) -> void:
    # The die resolved: it counts as a rolled die (fight/turn counters + opt-in triggers)
    # even if its target died mid-flight or the fight just ended - report before the
    # retarget/no-enemies checks below.
    Global.report_thrown_die_landed(dice_type, value)
    var final_target := target
    if final_target == null or not is_instance_valid(final_target):
        var alive := tree.get_nodes_in_group("enemies")
        if alive.is_empty():
            return
        final_target = alive[randi() % alive.size()]
    var die_hit := DamageEffect.new()
    # Trebuchet: per-fight flat bonus on every thrown die's landing hit.
    die_hit.amount = damage + Global.thrown_dice_bonus_fight
    die_hit.sound = hit_sound
    # Number pops where the die smashed (torso), not at the enemy root - with sequenced
    # volleys, each impact owning its own popup spot is what makes "this die dealt this"
    # readable at a glance.
    die_hit.popup_origin = thrown_impact_pos(final_target)
    die_hit.execute([final_target])

