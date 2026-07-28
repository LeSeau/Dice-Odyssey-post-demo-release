class_name Treasure
extends Control
@export var treasure_relic_pool: RelicPool  # Changed from Array[Relic] to RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var treasure_chest: TextureRect = $TreasureChest

# Opening flourish. The chest used to hard-cut to its open texture and then sit there
# for 1.55s of dead air before the reward fired, with no sound at all. Now the click
# buys a beat of anticipation (the lid rattles like it's about to give), then the pop
# lands with a light burst, a hit-stop and the treasure sting, and the reward follows
# promptly - see the retimed "open" animation in treasure.tscn.
const OPEN_SFX := preload("res://sfx/662471__fullstacksound__round_treasure.wav")
const RATTLE_TIME := 0.34
const RATTLE_SHAKES := 5
const RATTLE_STRENGTH := 6.0
# "open" swaps to the open-lid texture 0.2s in; the burst is timed to that frame so the
# light reads as coming out of the opening lid rather than preceding it.
const LID_POP_DELAY := 0.2
const BURST_COLOR := Color(1.0, 0.86, 0.42)
const BURST_TIME := 0.55
const BURST_START_SCALE := 0.35
const BURST_END_SCALE := 2.3

var found_relic: Relic
var _opening := false
var _chest_home := Vector2.ZERO


func _ready() -> void:
    _chest_home = treasure_chest.position


func generate_relic() -> void:
    if not treasure_relic_pool:
        push_error("No relic pool assigned!")
        return

    # Get a relic from the pool, same way your event does
    found_relic = treasure_relic_pool.get_random_relic(char_stats, relic_handler)


func _on_treasure_opened() -> void:
    Events.treasure_room_exited.emit(found_relic)


func _on_treasure_chest_gui_input(event: InputEvent) -> void:
    # Guarded on our own flag rather than the AnimationPlayer: the rattle happens BEFORE
    # "open" starts playing, so checking current_animation alone would let a second click
    # through during the anticipation beat.
    if _opening:
        return
    if event.is_action_pressed("left_mouse"):
        _opening = true
        _play_open_sequence()


func _play_open_sequence() -> void:
    # The idle pulse would fight the rattle for the position/scale channels.
    animation_player.stop()
    treasure_chest.position = _chest_home

    var rattle := create_tween()
    var step := RATTLE_TIME / float(RATTLE_SHAKES) * 0.5
    for i in RATTLE_SHAKES:
        var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35)) * RATTLE_STRENGTH
        rattle.tween_property(treasure_chest, "position", _chest_home + offset, step)
        rattle.tween_property(treasure_chest, "position", _chest_home, step)
    rattle.finished.connect(_burst_open)


func _burst_open() -> void:
    treasure_chest.position = _chest_home
    animation_player.play("open")
    SFXPlayer.play(OPEN_SFX)
    await get_tree().create_timer(LID_POP_DELAY, true, false, true).timeout
    _spawn_light_burst()
    Shaker.hit_stop(0.08, 0.05)


# Soft additive light blooming out of the opened lid - the same feathered radial-light
# recipe used for the shop deal glow and the map pawn shadow, kept as pure light with no
# hard edge.
func _spawn_light_burst() -> void:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
    gradient.colors = PackedColorArray([
        Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0),
    ])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 256
    texture.height = 256
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(0.5, 0.0)

    var material := CanvasItemMaterial.new()
    material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

    var burst := TextureRect.new()
    burst.texture = texture
    burst.material = material
    burst.modulate = Color(BURST_COLOR, 0.95)
    burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
    burst.size = Vector2(300, 300)
    burst.pivot_offset = Vector2(150, 150)
    burst.scale = Vector2(BURST_START_SCALE, BURST_START_SCALE)
    # Centred on the chest and drawn behind it, so the light reads as coming from inside.
    burst.position = _chest_home + treasure_chest.size / 2.0 - Vector2(150, 150)
    add_child(burst)
    move_child(burst, treasure_chest.get_index())

    var tween := burst.create_tween().set_parallel(true)
    tween.tween_property(burst, "scale", Vector2(BURST_END_SCALE, BURST_END_SCALE), BURST_TIME) \
        .set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    tween.tween_property(burst, "modulate:a", 0.0, BURST_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.chain().tween_callback(burst.queue_free)
