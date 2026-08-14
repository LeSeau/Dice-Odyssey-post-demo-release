extends Node

# Achievement system (autoload "AchievementManager"). Profile-scoped, not run-scoped:
# unlocks + lifetime counters persist in user://achievements.cfg across runs, mirroring
# SettingsManager's storage. Unlike SettingsManager/SaveManager this is a Node autoload
# (not a static class) because it needs to connect to Events signals and own the toast
# CanvasLayer that pops Steam-style from the bottom right.
#
# Trigger sources:
# - Events signals connected below (rolls, power, refuels)
# - direct calls from gameplay code that knows context signals don't carry:
#   run.gd::_on_battle_won (boss/elite), shop.gd (dice purchase - Events.dice_bought is
#   ALSO emitted by narrative events like Dice Forge, so the shop calls unlock directly),
#   dice.gd (lifetime power generated), card.gd + damage_effect.gd (damage window).
#
# The run-scoped Blue-roll counter lives in Global (blue_dice_rolled_this_run) so it
# follows the established reset_run_state()/save-dict lifecycle in global.gd + run.gd.

const SAVE_PATH := "user://achievements.cfg"
# Same sting the battle-reward screen plays on victory (battle_reward.gd's AudioStreamPlayer2D,
# no volume override there either) - was victory_daiso.mp3, changed on Julien's request so an
# achievement doesn't sound like "you just won the fight" when it pops mid-combat.
const JINGLE := preload("res://success.mp3")
const TOAST_SCRIPT := preload("res://scenes/ui/achievement_toast.gd")
const JINGLE_VOLUME_DB := 0.0

const BLUE_ROLLS_TARGET := 20
const POWER_REACH_TARGET := 15
const KABOOM_DAMAGE := 20  # "more than 20" - strictly greater unlocks
const REFUEL_DICE_MIN := 3
const REFUEL_LOW_POWER := 5

# Second wave of "fun/goofy, early-run" achievements (2026-07-16), all built on hooks
# that already exist - no new mechanics, just noticing moments that were already there.
const STREAK_LENGTH := 3       # "N in a row" for the hot/cold/crack streaks
const TURBO_DICE_COUNT := 8    # dice rolled in a single turn
const SCORCHED_EARTH_ENEMIES := 3  # enemies hit by one Magma roll
const OVERKILL_MARGIN := 15    # damage beyond what the target had left
const GLASS_CANNON_DAMAGE := 20  # single hit taken (and survived)

# Third wave (2026-07-19), same philosophy as the second wave above: no new mechanics,
# just new lifetime stats / one-shot checks wired onto signals and choke points that
# already existed (Events.*, RelicHandler.add_relic, shop.gd's dice-buy handlers).
const RESHUFFLE_MIN := 5           # cards moved discard->draw in one reshuffle
const GOLD_HOARD_TARGET := 300     # Gold held at once
const RELIC_HOARD_TARGET := 8      # Relics owned at once, single run
const TREASURE_CHESTS_TARGET := 15 # lifetime treasure rooms opened
const SHOP_CARDS_TARGET := 20      # lifetime cards bought from shops
const DICE_BOUGHT_TARGET := 30     # lifetime dice bought from the Dice Shop
const EVENTS_COMPLETED_TARGET := 25  # lifetime narrative events completed

# Display order for the pause menu's Achievements panel. "stat"+"target" = lifetime
# counter tracked here; "run_counter"+"target" = per-run counter read from Global.
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "i_am_powerful", "name": "I am powerful", "desc": "Reach 15 Power."},
	{
		"id": "they_see_me_rollin",
		"name": "They see me rollin",
		"desc": "Roll 20 Blue Dice in a single run.",
		"run_counter": "blue_dice_rolled_this_run",
		"target": BLUE_ROLLS_TARGET,
	},
	{"id": "kaboom", "name": "Kaboom", "desc": "Deal more than 20 damage with a single card."},
	{"id": "marine", "name": "Marine", "desc": "Defeat the Leviathan."},
	{
		"id": "lets_try_again",
		"name": "Let's try again",
		"desc": "Refuel at least 3 dice while holding less than 5 Power.",
	},
	{
		"id": "fueled_by_ambition",
		"name": "Fueled by ambition",
		"desc": "Give up a total of 100 Power by refueling your dice.",
		"stat": "power_refueled",
		"target": 100,
	},
	{"id": "customer", "name": "Customer", "desc": "Buy a dice from the Dice Shop."},
	{"id": "not_impressed", "name": "Not impressed", "desc": "Defeat an Elite enemy."},
	{
		"id": "unlimited_power",
		"name": "Unlimited Power",
		"desc": "Generate a total of 200 Power.",
		"stat": "power_generated",
		"target": 200,
	},
	{
		"id": "snake_eyes",
		"name": "Snake Eyes... Sort Of",
		"desc": "Crack the Evil Dice's cursed face 3 times in a row.",
	},
	{
		"id": "hot_hand",
		"name": "Hot Hand",
		"desc": "Roll the best possible face on your active Dice 3 times in a row.",
	},
	{
		"id": "ice_cold",
		"name": "Ice Cold",
		"desc": "Roll the worst possible face on your active Dice 3 times in a row.",
	},
	{
		"id": "scorched_earth",
		"name": "Scorched Earth",
		"desc": "Hit 3 or more enemies with a single Magma Dice roll.",
	},
	{
		"id": "turbo_mode",
		"name": "Turbo Mode",
		"desc": "Roll 8 or more dice in a single turn.",
	},
	{
		"id": "overkill",
		"name": "Overkill",
		"desc": "Land a killing blow for at least 15 more damage than the enemy had left.",
	},
	{
		"id": "glass_cannon",
		"name": "Glass Cannon",
		"desc": "Take 20 or more damage in a single hit and live to tell the tale.",
	},
	{
		"id": "untouchable",
		"name": "Untouchable",
		"desc": "Win a battle without losing a single HP.",
	},
	{
		"id": "full_cycle",
		"name": "Full Cycle",
		"desc": "Reshuffle 5 or more cards into your draw pile at once.",
	},
	{"id": "loaded", "name": "Loaded", "desc": "Hold 300 Gold at once."},
	{
		"id": "hoarder",
		"name": "Hoarder",
		"desc": "Own 8 Relics at the same time, in a single run.",
	},
	{
		"id": "conqueror",
		"name": "Conqueror",
		"desc": "Defeat the Leviathan a second time and finish a full run.",
	},
	{
		"id": "treasure_hunter",
		"name": "Treasure Hunter",
		"desc": "Open 15 treasure chests across your runs.",
		"stat": "treasure_chests_opened",
		"target": TREASURE_CHESTS_TARGET,
	},
	{
		"id": "retail_therapy",
		"name": "Retail Therapy",
		"desc": "Buy 20 cards from shops across your runs.",
		"stat": "cards_bought",
		"target": SHOP_CARDS_TARGET,
	},
	{
		"id": "dice_addict",
		"name": "Dice Addict",
		"desc": "Buy 30 Dice from the Dice Shop across your runs.",
		"stat": "dice_bought_from_shop",
		"target": DICE_BOUGHT_TARGET,
	},
	{
		"id": "well_traveled",
		"name": "Well Traveled",
		"desc": "Complete 25 narrative events across your runs.",
		"stat": "events_completed",
		"target": EVENTS_COMPLETED_TARGET,
	},
]

var _unlocked := {}
var _stats := {
	"power_refueled": 0,
	"power_generated": 0,
	"treasure_chests_opened": 0,
	"cards_bought": 0,
	"dice_bought_from_shop": 0,
	"events_completed": 0,
	# Lifetime run counter - not tied to any achievement. run.gd gates the run-start
	# dice loadout picker on it (picker appears from run #2 onward).
	"runs_started": 0,
}
# Stats change every roll, so they're flushed at quiet moments (turn end / battle end /
# quit) instead of writing the cfg file on every increment. Unlocks flush immediately.
var _dirty := false

var _toast_layer: CanvasLayer
var _toast_queue: Array[Dictionary] = []
var _toast_active := false

# Kaboom window: card.gd::play() opens/closes it around one card's apply_effects();
# damage_effect.gd reports every point of enemy damage dealt while it's open, so
# multi-hit and AoE cards count as one total.
var _card_damage_window_active := false
var _card_damage_total := 0

# Consecutive-roll streaks for Snake Eyes / Hot Hand / Ice Cold - fed by
# report_dice_roll() (dice.gd), reset the moment a roll breaks the pattern. Not
# scoped to a single turn or dice type on purpose: switching from Blue to Giant
# mid-streak and still rolling maxes is exactly the kind of goofy moment these
# are meant to reward, not something to gate out.
var _evil_crack_streak := 0
var _hot_streak := 0
var _cold_streak := 0

# Untouchable: reset on every real battle start, flipped by any HP loss, checked when
# the battle-over screen is dismissed. player_hit (character_stats.gd) only fires on an
# actual health decrease, so fully-blocked damage doesn't trip this - "hit" here means
# "lost HP", not "was attacked".
var _battle_hit_this_fight := false
# The tutorial fight's own victory path (tutorial_director.gd::_on_victory_continue_pressed)
# sets Global.tutorial_on = false BEFORE emitting battle_won, so unlock()'s usual tutorial
# gate doesn't catch it here - and the scripted tutorial never lets the player take a real
# hit, so every player would "earn" Untouchable for free on turn one. Snapshot tutorial_on
# at battle start instead of trusting its value at battle_won time.
var _battle_was_tutorial := false


func _ready() -> void:
	# ALWAYS: toasts keep animating (and can still pop) while the tree is paused by the
	# pause menu / map consult / battle-over panel.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_from_disk()

	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 90
	add_child(_toast_layer)

	Events.dice_rolled.connect(_on_dice_rolled)
	Events.red_dice_rolled.connect(_check_power_reached)
	Events.change_current_power.connect(_check_power_reached)
	Events.refuel_happened.connect(_on_refuel_happened)
	Events.player_turn_ended.connect(_flush_if_dirty)
	Events.battle_won.connect(_flush_if_dirty)
	Events.player_died.connect(_flush_if_dirty)

	Events.battle_started.connect(_on_battle_started)
	Events.player_hit.connect(_on_player_hit)
	Events.battle_won.connect(_check_untouchable)
	Events.deck_reshuffled.connect(_on_deck_reshuffled)
	Events.gold_changed.connect(_check_gold_hoard)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.event_exited.connect(_on_event_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_if_dirty()


func unlock(id: String) -> void:
	# Gate unlocks (not the underlying stat tracking) behind the tutorial fight - its
	# forced rolls/scripted turns would otherwise pop achievements for scripted, not
	# earned, moments. tutorial_on flips false the moment the tutorial ends
	# (tutorial_director.gd), so nothing is lost, just deferred.
	if Global.tutorial_on:
		return
	if _unlocked.get(id, false):
		return
	var def := _find_def(id)
	if def.is_empty():
		push_warning("AchievementManager: unknown achievement id '%s'" % id)
		return
	_unlocked[id] = true
	_dirty = true
	_flush_if_dirty()
	_enqueue_toast(def)


func is_unlocked(id: String) -> bool:
	return _unlocked.get(id, false)


# Lifetime counters (power_generated / power_refueled). Auto-unlocks any achievement
# whose "stat" matches once its target is reached.
func add_stat(key: String, amount: int) -> void:
	if amount <= 0:
		return
	_stats[key] = int(_stats.get(key, 0)) + amount
	_dirty = true
	for def in ACHIEVEMENTS:
		if def.get("stat", "") == key and _stats[key] >= int(def.get("target", 0)):
			unlock(def.id)


# Read-only lifetime counter access (run.gd gates the dice-loadout picker on
# "runs_started"). Returns 0 for unknown keys.
func get_stat(key: String) -> int:
	return int(_stats.get(key, 0))


# Immediate write-through for callers that can't wait for the next quiet-moment flush -
# run start counts "runs_started", and the player may quit from the very first map
# without ever ending a turn or a battle.
func flush() -> void:
	_flush_if_dirty()


# {current, target} for achievements with a counter, {} for one-shot ones. Once
# unlocked, current clamps to target so the menu never shows "27/20".
func get_progress(id: String) -> Dictionary:
	var def := _find_def(id)
	if def.is_empty() or not def.has("target"):
		return {}
	var target := int(def.target)
	var current := 0
	if def.has("stat"):
		current = int(_stats.get(def.stat, 0))
	elif def.has("run_counter"):
		current = int(Global.get(def.run_counter))
	if is_unlocked(id):
		current = target
	return {"current": mini(current, target), "target": target}


# --- Kaboom damage window (see card.gd::play / damage_effect.gd) ---

func begin_card_damage_window() -> void:
	_card_damage_window_active = true
	_card_damage_total = 0


func track_card_damage(amount: int) -> void:
	if _card_damage_window_active:
		_card_damage_total += amount


func end_card_damage_window() -> void:
	_card_damage_window_active = false
	if _card_damage_total > KABOOM_DAMAGE:
		unlock("kaboom")


# --- second-wave hooks (called directly from gameplay code, no signal for these) ---

# Called from dice.gd::_apply_roll_result right after Global.last_roll is set, with the
# full value set this roll was drawn from - dice.gd already computes min/max for its own
# "best roll" sound cue, this just piggybacks on that. Feeds Snake Eyes/Hot Hand/Ice Cold.
func report_dice_roll(dice_type: String, roll: int, min_value: int, max_value: int) -> void:
	if dice_type == "evil" and roll == 0:
		_evil_crack_streak += 1
	elif dice_type == "evil":
		_evil_crack_streak = 0
	if _evil_crack_streak >= STREAK_LENGTH:
		unlock("snake_eyes")

	if roll == max_value:
		_hot_streak += 1
	else:
		_hot_streak = 0
	if _hot_streak >= STREAK_LENGTH:
		unlock("hot_hand")

	if roll == min_value:
		_cold_streak += 1
	else:
		_cold_streak = 0
	if _cold_streak >= STREAK_LENGTH:
		unlock("ice_cold")


# Called from dice.gd's Magma roll branch with how many enemies the AoE just hit.
func report_magma_hit(enemies_hit: int) -> void:
	if enemies_hit >= SCORCHED_EARTH_ENEMIES:
		unlock("scorched_earth")


# Called from dice.gd right after Global.dice_amount_rolled_this_turn is incremented.
func report_dice_rolled_this_turn(count: int) -> void:
	if count >= TURBO_DICE_COUNT:
		unlock("turbo_mode")


# Called from damage_effect.gd with the enemy's HP just before the hit and the actual
# (target-modified) damage dealt - a kill that overshoots by a wide margin.
func report_enemy_hit(hp_before: int, damage_dealt: int) -> void:
	if hp_before > 0 and damage_dealt - hp_before >= OVERKILL_MARGIN:
		unlock("overkill")


# Called from damage_effect.gd with the damage the player just took and whether they're
# still standing afterwards.
func report_player_hit(damage_taken: int, survived: bool) -> void:
	if survived and damage_taken >= GLASS_CANNON_DAMAGE:
		unlock("glass_cannon")


# Called from relic_handler.gd::add_relic, the single choke point every relic the
# player owns (top-bar row) passes through - counts however many are on the bar right now.
func report_relic_count(count: int) -> void:
	if count >= RELIC_HOARD_TARGET:
		unlock("hoarder")


# --- third-wave signal handlers ---

func _on_battle_started() -> void:
	_battle_hit_this_fight = false
	_battle_was_tutorial = Global.tutorial_on


func _on_player_hit() -> void:
	_battle_hit_this_fight = true


func _check_untouchable() -> void:
	if not _battle_hit_this_fight and not _battle_was_tutorial:
		unlock("untouchable")


func _on_deck_reshuffled(card_count: int) -> void:
	if card_count >= RESHUFFLE_MIN:
		unlock("full_cycle")


func _check_gold_hoard() -> void:
	if Global.gold >= GOLD_HOARD_TARGET:
		unlock("loaded")


func _on_treasure_room_exited(_found_relic: Relic) -> void:
	add_stat("treasure_chests_opened", 1)


func _on_shop_card_bought(_card: Card, _gold_cost: int) -> void:
	add_stat("cards_bought", 1)


func _on_event_exited() -> void:
	add_stat("events_completed", 1)


# --- signal handlers ---

# Default args on purpose: dice_rolled is declared (active_dice, roll_value) but at least
# one emitter (triforce.gd) fires it with no args - a fixed 2-arg handler would silently
# never run for those emissions (see the signal-arity gotcha in tutorial_director.gd).
func _on_dice_rolled(dice_type = "", _roll_value = 0) -> void:
	_check_power_reached()
	if dice_type == "blue":
		Global.blue_dice_rolled_this_run += 1
		if Global.blue_dice_rolled_this_run >= BLUE_ROLLS_TARGET:
			unlock("they_see_me_rollin")


func _check_power_reached() -> void:
	if Global.roll_value >= POWER_REACH_TARGET:
		unlock("i_am_powerful")


# amount = Global.roll_value at refuel time (what every refuel card emits): the banked
# Power the player gives up, since dice_roll_reset follows right behind. roll_history
# still holds this turn's rolls at emit time - its size is the dice count refueled by
# Recombobulate/Catalyst/Voodoo (they all return roll_history.size() dice).
func _on_refuel_happened(amount = 0) -> void:
	if Global.roll_history.size() >= REFUEL_DICE_MIN and amount < REFUEL_LOW_POWER:
		unlock("lets_try_again")
	add_stat("power_refueled", amount)


# --- toast queue ---

func _enqueue_toast(def: Dictionary) -> void:
	_toast_queue.append(def)
	if not _toast_active:
		_show_next_toast()


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var def: Dictionary = _toast_queue.pop_front()
	# Deliberately untyped: setup()/finished live on the toast script, not Control,
	# and the script has no class_name (avoids the headless class-cache gotcha).
	var toast = TOAST_SCRIPT.new()
	toast.setup(def.name, def.desc)
	toast.finished.connect(_on_toast_finished.bind(toast))
	_toast_layer.add_child(toast)
	SFXPlayer.play(JINGLE, false, 1.0, JINGLE_VOLUME_DB)


func _on_toast_finished(toast: Control) -> void:
	toast.queue_free()
	_show_next_toast()


# --- persistence ---

func _find_def(id: String) -> Dictionary:
	for def in ACHIEVEMENTS:
		if def.id == id:
			return def
	return {}


func _load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for def in ACHIEVEMENTS:
		_unlocked[def.id] = bool(cfg.get_value("unlocked", def.id, false))
	for key: String in _stats.keys():
		_stats[key] = int(cfg.get_value("stats", key, 0))
	# Profile backfill: "runs_started" arrived with the run-start loadout picker
	# (2026-08-13), which unlocks from run #2 on. A profile that predates the stat has
	# obviously played before - any unlock or any nonzero lifetime stat proves it - and
	# should see the picker on its very NEXT run, not after one more "first" run.
	if int(_stats.get("runs_started", 0)) == 0:
		var played_before := false
		for def in ACHIEVEMENTS:
			if _unlocked.get(def.id, false):
				played_before = true
				break
		if not played_before:
			for key: String in _stats.keys():
				if key != "runs_started" and int(_stats[key]) > 0:
					played_before = true
					break
		if played_before:
			_stats["runs_started"] = 1
			_dirty = true


func _flush_if_dirty() -> void:
	if not _dirty:
		return
	_dirty = false
	var cfg := ConfigFile.new()
	for def in ACHIEVEMENTS:
		if _unlocked.get(def.id, false):
			cfg.set_value("unlocked", def.id, true)
	for key: String in _stats.keys():
		cfg.set_value("stats", key, _stats[key])
	cfg.save(SAVE_PATH)
