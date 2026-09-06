extends Node

# Verification harness for the bench enemy batch (2026-08-23).
# Loads every new EnemyStats, checks the resource + AI wiring, then renders each one
# at real battle size over the act-1 hallway background and records engine-measured
# rects (sprite / intent / HP bar) so the intent-vs-head clearance can be checked
# numerically - tightly cropped art is exactly what broke the Skeleton's intent before.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_bench_enemies.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env: BENCH_OUT = absolute output dir

const VIEW := Vector2i(1280, 720)
const BG := "res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png"
const SLUGS := [
    "brother_odd", "dice_warper", "miser",
    "dice_mimic", "pip_imp", "grave_grub", "amber_tick",
    "boar_knight", "gargoyle", "beetle_brute", "shackled_brute",
    "acolyte", "ash_priest", "stone_oracle", "plague_gambler",
    "pit_serpent", "die_knight", "storm_djinn", "bone_colossus",
]

var _bg_material: Material
var _out := ""
var _pass := 0
var _fail := 0
var _rows := []


func _check(ok: bool, label: String) -> void:
    if ok:
        _pass += 1
    else:
        _fail += 1
        print("[FAIL] ", label)


func _ready() -> void:
    _out = OS.get_environment("BENCH_OUT")
    if _out == "":
        _out = "user://bench_enemies"
    DirAccess.make_dir_recursive_absolute(_out)

    var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
    _bg_material = battle.get_node("Background").material
    battle.free()

    for slug in SLUGS:
        await _run(slug)
    # Same default box/position applied to SHIPPED art, to see what clearance the
    # incumbents actually get before deciding anything about the new crops.
    if OS.get_environment("BENCH_INCUMBENTS") != "":
        for path in ["res://enemies/crab/crab_enemy.tres",
                "res://enemies/goblin/goblin_enemy.tres",
                "res://enemies/machopeur/machopeur_enemy.tres",
                "res://enemies/satyr/satyr_enemy.tres",
                "res://enemies/lich/lich_enemy.tres",
                "res://enemies/plant/plant_enemy.tres"]:
            await _run_path(path, "SHIP:" + path.get_file().get_basename())

    print("\n%-16s %5s %5s %6s %7s %8s" % ["slug", "w", "h", "feet", "bar_gap", "intent_gap"])
    for r in _rows:
        var warn := "  <-- intent overlaps head" if r["intent_gap"] < 0 else ""
        print("%-16s %5d %5d %6.0f %7.0f %8.0f%s" % [r["slug"], r["w"], r["h"],
            r["feet"], r["bar_gap"], r["intent_gap"], warn])

    var f := FileAccess.open(_out.path_join("geometry.json"), FileAccess.WRITE)
    f.store_string(JSON.stringify(_rows, "  "))
    f.close()
    print("\n[bench] %d passed, %d failed -> %s" % [_pass, _fail, _out])
    get_tree().quit()


func _run(slug: String) -> void:
    await _run_path("res://enemies/%s/%s_enemy.tres" % [slug, slug], slug)


func _run_path(tres: String, slug: String) -> void:
    _check(ResourceLoader.exists(tres), slug + ": .tres exists")
    var stats: EnemyStats = load(tres)
    _check(stats != null, slug + ": stats loaded")
    if stats == null:
        return
    _check(stats.art != null, slug + ": art assigned")
    _check(stats.ai != null, slug + ": ai assigned")
    _check(stats.enemy_name != "", slug + ": enemy_name set")
    _check(stats.max_health > 0, slug + ": max_health > 0")

    var vp := SubViewport.new()
    vp.size = VIEW
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(vp)

    var bg := Sprite2D.new()
    bg.centered = false
    bg.texture = load(BG)
    bg.material = _bg_material
    vp.add_child(bg)

    var cam := Camera2D.new()
    cam.position = Vector2(639, 361)
    vp.add_child(cam)
    cam.make_current()

    var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
    player.position = Vector2(207, 426)
    vp.add_child(player)
    player.stats = load("res://characters/warrior/warrior.tres")

    var enemy: Enemy = (load("res://scenes/enemy/enemy.tscn") as PackedScene).instantiate()
    enemy.position = Vector2(892, 396)
    vp.add_child(enemy)
    enemy.stats = stats.create_instance()

    for i in 6:
        await get_tree().process_frame

    var picker := enemy.enemy_action_picker
    _check(picker != null and picker.get_child_count() > 0, slug + ": AI has actions")
    if picker and picker.get_child_count() > 0:
        var act: EnemyAction = picker.get_child(0)
        _check(act.is_performable(), slug + ": first action is_performable")
        _check(act.intent != null, slug + ": action has an intent")
    enemy.update_action()

    for i in 6:
        await get_tree().process_frame
    await RenderingServer.frame_post_draw

    var img := vp.get_texture().get_image()
    img.save_png(_out.path_join(slug + ".png"))

    var sprite: Sprite2D = enemy.sprite_2d
    var sr := sprite.get_rect()
    var s_top: float = sprite.to_global(sr.position).y
    var s_bottom: float = sprite.to_global(sr.end).y
    var bar: Control = enemy.stats_ui.get_node("Health/HealthBar")
    var bar_top: float = bar.get_global_rect().position.y
    var intent_bottom: float = enemy.intent_ui.get_global_rect().end.y
    _rows.append({
        "slug": slug, "w": int(sr.size.x), "h": int(sr.size.y),
        "feet": s_bottom, "bar_gap": bar_top - s_bottom,
        "intent_gap": s_top - intent_bottom,
    })
    vp.queue_free()
