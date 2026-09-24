class_name EnemyAction
extends Node

enum Type {CONDITIONAL, CHANCE_BASED}

@export var intent: Intent
@export var sound: AudioStream
@export var type: Type
@export_range(0.0, 10.0) var chance_weight := 0.0
@export var action_id := ""


@onready var accumulated_weight := 0.0

var enemy: Enemy
var target: Node2D
var modifiers: ModifierHandler


func is_performable() -> bool:
    return false


# True once this action has already run `limit` times in a row, so is_performable() should
# refuse it. Centralises the last_action/last_action_count idiom that used to be hand-rolled
# in four scripts (bigger_satyr_attack_debuff, medusa x2, leviathan).
#
# Enemy.do_turn() maintains the bookkeeping: it bumps last_action_count when the action_id
# repeats and resets it to 1 otherwise. So an action that has JUST run once reports count 1,
# which means hit_consecutive_cap(1) == "never twice in a row" and hit_consecutive_cap(2)
# == "never three times in a row".
#
# Requires action_id to be set - an empty id can never be tracked, and two actions sharing
# an id share one counter (Bigger Satyr's turn-1 opener does that on purpose, so the opener
# counts towards the screech cap).
func hit_consecutive_cap(limit: int) -> bool:
    if action_id == "":
        return false
    return enemy != null and enemy.last_action == action_id and enemy.last_action_count >= limit


# The nearest other LIVING body in this fight, or null when this enemy is the last one up.
# Centralises the one thing that is easy to get wrong about it: an Enemy leaves the `enemies`
# group in the FIRST line of its death sequence, before the death animation gets any time, so
# a corpse can never be returned here - a health check on top is belt-and-braces for the frame
# in which stats hit 0 but the sequence has not run yet.
#
# Written for the Parity Brothers, where both beats branch on it: the guard hands its Strength
# to the twin, and once the twin is gone the survivor drops the guard and strikes every turn.
func living_ally() -> Enemy:
    if enemy == null or not is_instance_valid(enemy):
        return null
    for node in enemy.get_tree().get_nodes_in_group("enemies"):
        var other := node as Enemy
        if other == null or other == enemy:
            continue
        if not is_instance_valid(other) or other.is_queued_for_deletion():
            continue
        if other.stats == null or other.stats.health <= 0:
            continue
        return other
    return null


func perform_action() -> void:
    pass

func update_intent_text() -> void:
    intent.current_text = intent.base_text


# ---------------------------------------------------------------------------------------------
# Attack motion (2026-09-23). Every attack script used to hand-build the same glide tween; they
# all go through here now, so how an enemy swings is tuned in ONE place
# (scenes/enemy/enemy_attack_motion.gd).
#
# steps - exactly what used to sit between the arrival and the return in the old tween: a
#         Callable runs on a contact, consecutive Callables share one contact (damage + a status),
#         and a number is the gap before the NEXT contact (a multi-hit's later blow).
# hold  - how long the attacker stays after its last contact before going home.
# power - the per-hit damage, only used to size the wind-up (bigger hits coil longer).
# motion - LUNGE for melee, CAST for casters (they throw a bolt instead of running over).
#
# Emits Events.enemy_action_completed when the motion ends, like the old tween did.
# ---------------------------------------------------------------------------------------------
enum Motion { LUNGE, CAST }

const AttackMotion := preload("res://scenes/enemy/enemy_attack_motion.gd")
const CAST_COLOR_DEFAULT := Color(0.75, 0.55, 1.0)


func run_attack(steps: Array, hold := 0.25, power := 0, motion := Motion.LUNGE,
        cast_color := CAST_COLOR_DEFAULT) -> void:
    if enemy == null or not is_instance_valid(enemy) or target == null or not is_instance_valid(target):
        return
    if motion == Motion.CAST:
        AttackMotion.cast(enemy, target, steps, hold, power, cast_color)
    else:
        AttackMotion.lunge(enemy, target, steps, hold, power)
