extends Node

# Harness for the card reward inspect overlay (right-click -> magnified card + upgrade toggle).
# Boots the REAL card_rewards.tscn with real pool cards, drives the overlay through its actual
# entry points, asserts behaviour, and renders PNGs of every state.
#
# Run (never --headless: that forces the dummy driver and saves blank images):
#   "/c/Users/julie/Desktop/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe" \
#     --path . res://debug_card_inspect.tscn --rendering-driver opengl3 \
#     --resolution 1280x720 --position 2000,2000 > inspect_log.txt 2>&1
#
# CardRewards is a full-rect ColorRect: parent it to a plain Node (or straight into the
# SubViewport) - under a Node2D its anchors resolve against size 0 and the whole screen
# collapses to the origin.

const CARD_REWARDS := preload("res://scenes/ui/card_rewards.tscn")
const POOL := preload("res://characters/warrior/warrior_draftable_cards.tres")
const OUT_DIR := "res://inspect_renders"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _viewport: SubViewport
var _screen: CardRewards
var _picked_card: Card = null
var _passes := 0
var _fails := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
    if ok:
        _passes += 1
        print("  PASS  %s %s" % [label, detail])
    else:
        _fails += 1
        print("  FAIL  %s %s" % [label, detail])


func _ready() -> void:
    MusicPlayer.stop()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    await _run()
    await _run_shop()
    print("\n==== inspect overlay: %d passed, %d failed ====" % [_passes, _fails])
    get_tree().quit(1 if _fails > 0 else 0)


func _run() -> void:
    var picks: Array[Card] = _pick_cards(3)
    _check("A0 pool gave 3 upgradable cards", picks.size() == 3,
        "-> %s" % [picks.map(func(c): return c.name)])
    if picks.size() < 3:
        return

    _viewport = SubViewport.new()
    _viewport.size = VIEWPORT_SIZE
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _viewport.transparent_bg = false
    add_child(_viewport)

    _screen = CARD_REWARDS.instantiate() as CardRewards
    _viewport.add_child(_screen)
    _screen.rewards = picks
    await _settle(50)
    await _shot("01_reward_screen")

    var hint: Label = _screen.get_node_or_null("InspectHint") as Label
    _check("A1 discoverability hint exists", hint != null and hint.visible)
    var hint_rect: Rect2 = hint.get_global_rect()
    var skip_rect: Rect2 = _screen.skip_card_reward.get_global_rect()
    _check("A2 hint clears the Skip button", not hint_rect.intersects(skip_rect),
        "-> hint %s vs skip %s" % [hint_rect, skip_rect])
    _check("A3 hint stays on screen",
        hint_rect.end.y <= VIEWPORT_SIZE.y and hint_rect.position.y >= 0.0)

    # --- open -------------------------------------------------------------------------------
    _screen._open_inspect(picks[0])
    await _settle(30)
    _check("A4 hint hidden while inspecting", not hint.visible)
    var overlay: Node = _screen._inspect_overlay
    _check("B1 right-click opened an overlay", overlay != null and is_instance_valid(overlay))
    if overlay == null:
        return
    _check("B2 overlay sits below tooltips (layer 100)", overlay.layer == 99,
        "-> layer %d" % overlay.layer)
    _check("B3 opened on the clicked card", overlay.index == 0)
    # The backstop is what stops a click reaching (and picking) a card behind the overlay.
    var backstop: ColorRect = overlay._backstop
    _check("B3b backstop covers the viewport and eats clicks",
        backstop.mouse_filter == Control.MOUSE_FILTER_STOP
            and backstop.get_global_rect().encloses(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))),
        "-> %s" % backstop.get_global_rect())
    await _shot("02_inspect_base")

    var menu: CardMenuUI = overlay._card_menu
    _check("B4 showing the base card", menu.card == picks[0],
        "-> %s" % menu.card.name)
    # The magnified card is the whole reason the tooltip geometry had to become scale-aware.
    var rect: Rect2 = menu.get_global_rect()
    _check("B5 scaled rect tracks CARD_SCALE",
        is_equal_approx(rect.size.x, 140.0 * overlay.CARD_SCALE),
        "-> %.1f x %.1f" % [rect.size.x, rect.size.y])
    print("  geom  size=%s scale=%s global_rect=%s" % [menu.size, menu.scale, rect])
    # The tooltip column anchors off this rect; `size` alone (unscaled) is what used to be wrong.
    _check("B6 tooltip anchor uses the scaled width, not size.x",
        not is_equal_approx(rect.size.x, menu.size.x),
        "-> rect %.0f vs size %.0f" % [rect.size.x, menu.size.x])

    # --- upgrade toggle ---------------------------------------------------------------------
    _check("C1 toggle visible for an upgradable card", overlay._toggle_button.visible)
    overlay._on_toggle_pressed()
    await _settle(20)
    _check("C2 toggle shows the upgraded version",
        menu.card == picks[0].upgraded_version,
        "-> %s" % menu.card.name)
    _check("C3 upgraded card reports upgraded", menu.card.upgraded)
    _check("C4 toggle label flipped",
        overlay._toggle_button.text == overlay.TOGGLE_TEXT_HIDE,
        "-> %s" % overlay._toggle_button.text)
    await _shot("03_inspect_upgraded")

    overlay._on_toggle_pressed()
    await _settle(20)
    _check("C5 toggling back restores the base card", menu.card == picks[0])
    overlay._on_toggle_pressed()
    await _settle(20)

    # --- paging -----------------------------------------------------------------------------
    _check("D1 left arrow disabled on the first card", overlay._left_button.disabled)
    _check("D2 right arrow live on the first card", not overlay._right_button.disabled)
    overlay._page(1)
    await _settle(20)
    _check("D3 paged to card 2", overlay.index == 1)
    _check("D4 upgrade preview is sticky across paging",
        menu.card == picks[1].upgraded_version, "-> %s" % menu.card.name)
    _check("D5 page label tracks position", overlay._page_label.text == "2 / 3",
        "-> %s" % overlay._page_label.text)
    await _shot("04_inspect_paged_upgraded")

    overlay._page(1)
    await _settle(15)
    _check("D6 right arrow disabled on the last card", overlay._right_button.disabled)
    overlay._page(1)
    await _settle(5)
    _check("D7 paging past the end is clamped, not wrapped", overlay.index == 2)

    # --- close ------------------------------------------------------------------------------
    overlay._close()
    await _settle(30)
    _check("E1 overlay freed on close", not is_instance_valid(overlay))
    _check("E2 screen cleared its handle", _screen._inspect_overlay == null)
    _check("E3 hint restored after close", hint.visible)
    await _shot("05_after_close")

    # --- the pick path still works ----------------------------------------------------------
    # NEGATIVE CONTROL for the new right-click branch: a right press must NOT pick, and the
    # left press directly after it must still pick normally.
    var right := InputEventMouseButton.new()
    right.button_index = MOUSE_BUTTON_RIGHT
    right.pressed = true
    _screen._on_card_menu_clicked(right, _screen._card_menus[0], picks[0])
    await _settle(10)
    _check("F1 right-click does not pick", not _screen._picked)
    _check("F2 right-click re-opened the overlay", _screen._inspect_overlay != null)
    _screen._inspect_overlay._close()
    await _settle(25)

    _screen.card_reward_selected.connect(func(c): _picked_card = c)
    var left := InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    _screen._on_card_menu_clicked(left, _screen._card_menus[0], picks[0])
    await _settle(2)
    _check("F3 left-click still picks", is_instance_valid(_screen) and _screen._picked)
    await _settle(60)
    _check("F4 picked the BASE card, never the upgrade", _picked_card == picks[0],
        "-> %s" % ("null" if _picked_card == null else _picked_card.name))
    _check("F5 reward screen tore down after the pick", not is_instance_valid(_screen))


# --- card shop --------------------------------------------------------------------------------
# Same overlay, second entry point. Boot recipe copied from debug_shop_rework.gd.
func _run_shop() -> void:
    var vp := SubViewport.new()
    vp.size = VIEWPORT_SIZE
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(vp)
    _viewport = vp

    Global.gold = 500
    var warrior := load("res://characters/warrior/warrior.tres") as CharacterStats
    var char_stats := warrior.create_instance() as CharacterStats
    var relic_handler: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
    vp.add_child(relic_handler)
    var shop: Shop = (load("res://scenes/shop/card_shop.tscn") as PackedScene).instantiate()
    shop.char_stats = char_stats
    shop.run_stats = RunStats.new()
    shop.relic_handler = relic_handler
    vp.add_child(shop)
    shop.populate_shop()
    MusicPlayer.stop()
    await _settle(25)

    var shop_cards: Array[Node] = shop.cards.get_children()
    _check("G0 shop stocked 5 cards", shop_cards.size() == 5, "-> %d" % shop_cards.size())
    if shop_cards.size() < 2:
        return

    var hint: Label = shop.get_node_or_null("InspectHint") as Label
    _check("G1 shop hint exists", hint != null and hint.visible)
    var leave_rect: Rect2 = (shop.get_node("Button") as Control).get_global_rect()
    _check("G2 shop hint clears the Leave button",
        not hint.get_global_rect().intersects(leave_rect),
        "-> hint %s vs leave %s" % [hint.get_global_rect(), leave_rect])
    # Centred text looks misplaced unless it is centred on the CARD ROW, which sits left of
    # screen centre because the deal/removal stalls own the right-hand column.
    var row_center: float = shop.cards.get_global_rect().get_center().x
    var hint_center: float = hint.get_global_rect().get_center().x
    _check("G2b shop hint is centred under the card row", absf(hint_center - row_center) <= 30.0,
        "-> hint %.0f vs row %.0f" % [hint_center, row_center])
    await _shot("06_card_shop")

    # Right-click the SECOND card, so a wrong start index can't hide behind a default of 0.
    var target: ShopCard = shop_cards[1] as ShopCard
    var target_card: Card = target.card
    var gold_before: int = Global.gold
    var right := InputEventMouseButton.new()
    right.button_index = MOUSE_BUTTON_RIGHT
    right.pressed = true
    target._on_card_gui_input(right)
    await _settle(30)

    var overlay: Node = shop._inspect_overlay
    _check("G3 right-click opened the overlay in the shop",
        overlay != null and is_instance_valid(overlay))
    if overlay == null:
        return
    _check("G4 pages every card still on the shelf", overlay.cards.size() == 5,
        "-> %d" % overlay.cards.size())
    _check("G5 opened on the clicked card", overlay.index == 1 and overlay._card_menu.card == target_card,
        "-> index %d, %s" % [overlay.index, overlay._card_menu.card.name])
    # NEGATIVE CONTROL: right-click must never reach the buy path.
    _check("G6 right-click did not buy", not target.is_sold() and Global.gold == gold_before,
        "-> gold %d -> %d" % [gold_before, Global.gold])
    _check("G7 shop hint hidden while inspecting", not hint.visible)

    if target_card.can_be_upgraded():
        overlay._on_toggle_pressed()
        await _settle(20)
        _check("G8 upgrade preview works in the shop",
            overlay._card_menu.card == target_card.upgraded_version,
            "-> %s" % overlay._card_menu.card.name)
    await _shot("07_card_shop_inspect_upgraded")

    overlay._close()
    await _settle(30)
    _check("G9 overlay freed, hint restored",
        not is_instance_valid(overlay) and shop._inspect_overlay == null and hint.visible)

    # And buying still works right after inspecting.
    var left := InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    target._on_card_gui_input(left)
    await _settle(10)
    _check("G10 left-click still buys", target.is_sold())
    _check("G11 a sold slot drops out of the inspect list",
        shop._cards_on_offer().size() == 4, "-> %d" % shop._cards_on_offer().size())


func _pick_cards(count: int) -> Array[Card]:
    var out: Array[Card] = []
    for entry in POOL.cards:
        if entry != null and entry.can_be_upgraded():
            out.append(entry)
        if out.size() >= count:
            break
    return out


func _settle(frames: int) -> void:
    for i in frames:
        await get_tree().process_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    var image: Image = _viewport.get_texture().get_image()
    image.save_png("%s/%s.png" % [OUT_DIR, name])
    print("  shot  %s" % name)
