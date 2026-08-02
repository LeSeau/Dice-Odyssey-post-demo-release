extends Node
# Verifies the EXPORTED pck's relic chain end-to-end: mounts build/web/index.pck
# over the project (replace = true), then loads both relic pools fresh from the
# pck and runs the real RelicPool.get_random_relic() path that broke in the
# 2026-08-02 itch build (pools binary-converted to empty Array[Relic]).
# Run:  Godot_v4.3-stable_win64_console.exe --path . res://debug_pck_relic_check.tscn --headless

const PCK_PATH := "res://build/web/index.pck"

var _fails := 0


func _ready() -> void:
	var mounted := ProjectSettings.load_resource_pack(PCK_PATH, true)
	_check(mounted, "pck mounted with replace=true")
	if not mounted:
		_finish()
		return

	_verify_pool("res://treasure_relic_pool.tres")
	_verify_pool("res://shop_relic_pool.tres")
	_verify_treasure_flow()
	_finish()


func _verify_pool(path: String) -> void:
	print("\n--- %s (from pck) ---" % path)
	var pool = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(pool != null, "pool resource loads")
	if pool == null:
		return
	_check(pool is RelicPool, "pool is RelicPool (script resolved)")
	var entries: Array = pool.pool
	_check(entries.size() == 26, "pool has 26 entries (got %d)" % entries.size())
	var bad := 0
	for r in entries:
		if r == null or not (r is Relic):
			bad += 1
			continue
		if r.relic_name.is_empty() or r.icon == null or r.tooltip.is_empty():
			print("    BAD FIELDS: %s (name='%s' icon=%s tooltip_len=%d)" % [
					r.resource_path, r.relic_name, r.icon != null, r.tooltip.length()])
			bad += 1
	_check(bad == 0, "all entries are real Relics with name/icon/tooltip (%d bad)" % bad)


func _verify_treasure_flow() -> void:
	print("\n--- get_random_relic through the real scripts ---")
	var pool = ResourceLoader.load("res://treasure_relic_pool.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if pool == null:
		_check(false, "pool available for flow test")
		return
	var handler: RelicHandler = load("res://scenes/relic_handler/relic_handler.tscn").instantiate()
	add_child(handler)
	var stats: CharacterStats = load("res://characters/warrior/warrior.tres").create_instance()
	var names := {}
	var nulls := 0
	for i in 40:
		var relic: Relic = pool.get_random_relic(stats, handler)
		if relic == null:
			nulls += 1
		else:
			names[relic.relic_name] = true
	_check(nulls == 0, "40 draws, zero null relics (got %d nulls)" % nulls)
	_check(names.size() >= 10, "draws show variety (%d distinct relics)" % names.size())
	print("    sample: ", ", ".join(names.keys().slice(0, 8)))


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		_fails += 1
		print("  FAIL  ", label)


func _finish() -> void:
	print("\n%s (%d failures)" % ["ALL PCK CHECKS PASSED" if _fails == 0 else "PCK CHECKS FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
