extends CanvasLayer

# Card inspect overlay - the "right-click a card to look at it properly" screen, modelled on
# STS2's NInspectCardScreen (sts2_ref/src/Core/Nodes/Screens/NInspectCardScreen.cs): a dimmed
# backstop, one magnified card, arrows to page through the other cards on offer, and a toggle
# that re-renders that same card as its upgraded version. Note STS2 toggles ONE card in place
# rather than showing before/after side by side - their side-by-side view is the rest site
# (NUpgradePreview), which is our campfire UpgradeConfirmPanel, a different feature.
#
# Three structural notes:
#
# 1. No .tscn and no class_name, on purpose. Everything is built in code (same pattern as
#    run_stats_panel.gd / achievement_toast.gd): a fresh class_name doesn't resolve until the
#    editor rescans, and a new .tscn is one more file an open editor can re-save from a stale
#    buffer. Consumers preload this .gd and call .new().
#
# 2. layer 99 is load-bearing, not arbitrary. Hover tooltips (tooltip.tscn) are their own
#    CanvasLayer at layer 100 parented to the tree root, so an overlay sitting ABOVE them would
#    bury the very keyword tooltips this screen exists to let you read. 99 still covers the
#    reward screen, which is plain Control/ColorRect on the base canvas. The only thing that
#    outranks us is card_rewards' one-shot tutorial popups on layer 101 - the caller refuses to
#    open underneath one of those rather than stacking two modals.
#
# 3. The card sits inside a mouse_filter STOP slot sized to its SCALED footprint. Visuals and
#    CardFrame inside card_menu_ui.tscn are both PASS, so without that slot a click on the card
#    would fall straight through to the backstop and close the overlay you just opened.

signal closed

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")
const BELWE := preload("res://Belwe Bold/Belwe Bold.otf")

# The shop plates are the game's button language everywhere (see the label/chrome pass): teal
# for ordinary buttons, gold reserved for the one emphasis button on a screen - which here is
# the upgrade toggle, the whole reason this overlay exists.
const TEAL_NORMAL := preload("res://scenes/shop/shop_button_normal.tres")
const TEAL_HOVER := preload("res://scenes/shop/shop_button_hover.tres")
const TEAL_PRESSED := preload("res://scenes/shop/shop_button_pressed.tres")
const GOLD_NORMAL := preload("res://scenes/shop/shop_button_gold_normal.tres")
const GOLD_HOVER := preload("res://scenes/shop/shop_button_gold_hover.tres")
const GOLD_PRESSED := preload("res://scenes/shop/shop_button_gold_pressed.tres")

# Paging reuses the card swish the reward screen already reveals/picks with, so the whole
# screen stays one instrument. The toggle borrows the campfire's forge "cling" (the sound
# already attached to upgrading a card), pitched down when reverting to the base version.
const PAGE_SFX := preload("res://drawcardsound.wav")
const PAGE_SFX_VOLUME_DB := -8.0
const OPEN_SFX_PITCH := 0.9
const OPEN_SFX_VOLUME_DB := -10.0
const TOGGLE_SFX := preload("res://sounds/blacksmithsound.wav")
const TOGGLE_SFX_VOLUME_DB := -9.0
const TOGGLE_SFX_PITCH_ON := 1.0
const TOGGLE_SFX_PITCH_OFF := 0.82

const LAYER := 99
const BACKSTOP_COLOR := Color(0.02, 0.02, 0.04, 0.88)

# --- Layout, all as offsets from screen centre so it survives any window size ---------------
# At CARD_SCALE 2.4 the 140x210 card renders 336x504 and spans y 68..572 of the 720 design
# height, which leaves clean room for the toggle below it and keeps its hover-tooltip column
# (x 816..1020) clear of the right arrow at x 1083..1157.
const CARD_BASE_SIZE := Vector2(140.0, 210.0)
const CARD_SCALE := 2.4
const CARD_CENTER_OFFSET := Vector2(0.0, -40.0)
const ARROW_SIZE := Vector2(74.0, 74.0)
const ARROW_CENTER_OFFSET_X := 480.0
const TOGGLE_SIZE := Vector2(300.0, 54.0)
const TOGGLE_CENTER_OFFSET := Vector2(0.0, 258.0)
const PAGE_CENTER_OFFSET := Vector2(0.0, -324.0)
const HINT_CENTER_OFFSET := Vector2(0.0, 318.0)

const CREAM := Color(1.0, 0.964706, 0.886275)
const HINT_ALPHA := 0.6
const SHADOW := Color(0, 0, 0, 0.25)

const TOGGLE_TEXT_SHOW := "Preview Upgrade"
const TOGGLE_TEXT_HIDE := "Show Original"
const HINT_TEXT_SINGLE := "Esc or right-click to close"
const HINT_TEXT_PAGED := "Esc or right-click to close        <  >  to browse"

const OPEN_TIME := 0.22
const OPEN_START_SCALE := 0.88
const CLOSE_TIME := 0.14
const SWAP_FLASH_COLOR := Color(1.45, 1.42, 1.28)

var cards: Array[Card] = []
var index := 0

var _showing_upgraded := false
var _closing := false
var _card_menu: CardMenuUI = null
var _backstop: ColorRect = null
var _chrome: Control = null
var _left_button: Button = null
var _right_button: Button = null
var _toggle_button: Button = null
var _page_label: Label = null
var _hint_label: Label = null
var _swap_tween: Tween = null


func _ready() -> void:
    layer = LAYER
    _build()


# Call after add_child(). Kept separate from _ready so the caller can hand over the card list
# and starting index without having to configure the node before it enters the tree.
func setup(card_list: Array[Card], start_index: int) -> void:
    cards = card_list
    if not is_node_ready():
        await ready
    if cards.is_empty():
        _finish_close()
        return
    index = clampi(start_index, 0, cards.size() - 1)
    _refresh(false)
    _play_open()


func _build() -> void:
    _backstop = ColorRect.new()
    _backstop.name = "Backstop"
    _backstop.color = BACKSTOP_COLOR
    _backstop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _backstop.mouse_filter = Control.MOUSE_FILTER_STOP
    _backstop.gui_input.connect(_on_backstop_gui_input)
    add_child(_backstop)

    # Everything except the card, so the open/close fade is one tween on one node. A bare
    # Control defaults to mouse_filter STOP, which would swallow every click aimed at the
    # things inside it - IGNORE here, the buttons set their own.
    _chrome = Control.new()
    _chrome.name = "Chrome"
    _chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
    _chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_chrome)

    var slot := Control.new()
    slot.name = "CardSlot"
    slot.mouse_filter = Control.MOUSE_FILTER_STOP
    _place_centered(slot, CARD_CENTER_OFFSET, CARD_BASE_SIZE * CARD_SCALE)
    _chrome.add_child(slot)

    _card_menu = CARD_MENU_UI.instantiate() as CardMenuUI
    _card_menu.interactive = false
    slot.add_child(_card_menu)
    _card_menu.size = CARD_BASE_SIZE
    # Scaling about the centre pivot pins the card's midpoint to `position + pivot_offset`
    # whatever CARD_SCALE is, so the magnified card stays centred on the slot by construction.
    _card_menu.pivot_offset = CARD_BASE_SIZE / 2.0
    _card_menu.position = (slot.size / 2.0) - _card_menu.pivot_offset
    _card_menu.scale = Vector2.ONE * CARD_SCALE

    _left_button = _make_button("<", ARROW_SIZE, 34, false)
    _place_centered(_left_button, Vector2(-ARROW_CENTER_OFFSET_X, CARD_CENTER_OFFSET.y), ARROW_SIZE)
    _left_button.pressed.connect(_page.bind(-1))
    _chrome.add_child(_left_button)

    _right_button = _make_button(">", ARROW_SIZE, 34, false)
    _place_centered(_right_button, Vector2(ARROW_CENTER_OFFSET_X, CARD_CENTER_OFFSET.y), ARROW_SIZE)
    _right_button.pressed.connect(_page.bind(1))
    _chrome.add_child(_right_button)

    _toggle_button = _make_button(TOGGLE_TEXT_SHOW, TOGGLE_SIZE, 22, true)
    _place_centered(_toggle_button, TOGGLE_CENTER_OFFSET, TOGGLE_SIZE)
    _toggle_button.pressed.connect(_on_toggle_pressed)
    _chrome.add_child(_toggle_button)

    _page_label = _make_label("", 20, 0.85)
    _place_centered(_page_label, PAGE_CENTER_OFFSET, Vector2(200.0, 30.0))
    _chrome.add_child(_page_label)

    _hint_label = _make_label(HINT_TEXT_SINGLE, 15, 0.55)
    _place_centered(_hint_label, HINT_CENTER_OFFSET, Vector2(700.0, 26.0))
    _chrome.add_child(_hint_label)


func _make_button(text: String, button_size: Vector2, font_size: int, gold: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = button_size
    # Without this a focused Button eats ui_left/ui_right for focus navigation, which are the
    # very actions _input() uses to page between cards.
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_override("font", BELWE)
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", CREAM)
    button.add_theme_color_override("font_hover_color", CREAM)
    button.add_theme_color_override("font_pressed_color", CREAM)
    button.add_theme_color_override("font_disabled_color", Color(CREAM.r, CREAM.g, CREAM.b, 0.35))
    button.add_theme_color_override("font_shadow_color", SHADOW)
    button.add_theme_constant_override("shadow_offset_x", 3)
    button.add_theme_constant_override("shadow_offset_y", 2)
    button.add_theme_stylebox_override("normal", GOLD_NORMAL if gold else TEAL_NORMAL)
    button.add_theme_stylebox_override("hover", GOLD_HOVER if gold else TEAL_HOVER)
    button.add_theme_stylebox_override("pressed", GOLD_PRESSED if gold else TEAL_PRESSED)
    # A button with no `disabled` override falls through to the project theme and turns into a
    # visibly different box - reuse its own normal plate and let the dimmed font carry the state.
    button.add_theme_stylebox_override("disabled", GOLD_NORMAL if gold else TEAL_NORMAL)
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    ButtonFeel.attach(button)
    return button


func _make_label(text: String, font_size: int, alpha: float) -> Label:
    return make_hint_label(text, font_size, alpha)


# Shared by every screen that offers inspecting (reward picker, card shop). Right-click is an
# invisible affordance, so each of those screens has to write it down - and they should say it
# in one voice, from one place, rather than each hand-rolling a Label the next pass can drift.
static func make_hint_label(text: String, font_size: int, alpha: float = HINT_ALPHA) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font", BELWE)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(CREAM.r, CREAM.g, CREAM.b, alpha))
    label.add_theme_color_override("font_shadow_color", SHADOW)
    label.add_theme_constant_override("shadow_offset_x", 3)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label


# Anchors a control to the viewport centre and offsets it from there, so the layout holds at
# any window size instead of being pinned to 1280x720 pixel coordinates.
func _place_centered(control: Control, center_offset: Vector2, rect_size: Vector2) -> void:
    control.anchor_left = 0.5
    control.anchor_top = 0.5
    control.anchor_right = 0.5
    control.anchor_bottom = 0.5
    control.offset_left = center_offset.x - (rect_size.x / 2.0)
    control.offset_top = center_offset.y - (rect_size.y / 2.0)
    control.offset_right = center_offset.x + (rect_size.x / 2.0)
    control.offset_bottom = center_offset.y + (rect_size.y / 2.0)


func _current_card() -> Card:
    return cards[index]


func _refresh(flash: bool = true) -> void:
    var base_card: Card = _current_card()
    var upgradable: bool = base_card.can_be_upgraded()
    if not upgradable:
        _showing_upgraded = false
    var shown: Card = base_card.upgraded_version if (_showing_upgraded and upgradable) else base_card
    _card_menu.display_card(shown)

    _toggle_button.visible = upgradable
    _toggle_button.text = TOGGLE_TEXT_HIDE if _showing_upgraded else TOGGLE_TEXT_SHOW

    var paged: bool = cards.size() > 1
    _left_button.visible = paged
    _right_button.visible = paged
    _page_label.visible = paged
    _page_label.text = "%d / %d" % [index + 1, cards.size()]
    _hint_label.text = HINT_TEXT_PAGED if paged else HINT_TEXT_SINGLE
    # Clamped rather than wrapping, so the ends of a three-card offer are readable at a glance
    # (STS2 hides them outright; dimming keeps the layout from jumping).
    _left_button.disabled = index <= 0
    _right_button.disabled = index >= cards.size() - 1

    if flash:
        _flash_card()


# Brief overbright pop so a swap registers as an event. Lives on Visuals, never on the card
# root: the root's modulate/scale belong to the open/close tween, and two tweens fighting over
# one property is how these beats break.
func _flash_card() -> void:
    var visuals := _card_menu.get_node("Visuals") as Control
    if _swap_tween and _swap_tween.is_valid():
        _swap_tween.kill()
    _swap_tween = visuals.create_tween()
    _swap_tween.tween_property(visuals, "modulate", SWAP_FLASH_COLOR, 0.07) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _swap_tween.tween_property(visuals, "modulate", Color.WHITE, 0.18) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _page(delta: int) -> void:
    if _closing or cards.size() <= 1:
        return
    var next := clampi(index + delta, 0, cards.size() - 1)
    if next == index:
        return
    index = next
    _refresh()
    SFXPlayer.play(PAGE_SFX, false, 1.0, PAGE_SFX_VOLUME_DB)


func _on_toggle_pressed() -> void:
    if _closing or not _current_card().can_be_upgraded():
        return
    _showing_upgraded = not _showing_upgraded
    _refresh()
    var pitch: float = TOGGLE_SFX_PITCH_ON if _showing_upgraded else TOGGLE_SFX_PITCH_OFF
    SFXPlayer.play(TOGGLE_SFX, false, pitch, TOGGLE_SFX_VOLUME_DB)


func _play_open() -> void:
    SFXPlayer.play(PAGE_SFX, false, OPEN_SFX_PITCH, OPEN_SFX_VOLUME_DB)
    var target_alpha: float = BACKSTOP_COLOR.a
    _backstop.color.a = 0.0
    _chrome.modulate.a = 0.0
    _card_menu.modulate.a = 0.0
    _card_menu.scale = Vector2.ONE * CARD_SCALE * OPEN_START_SCALE

    var fade := create_tween().set_parallel()
    fade.tween_property(_backstop, "color:a", target_alpha, OPEN_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    fade.tween_property(_chrome, "modulate:a", 1.0, OPEN_TIME).set_delay(0.06)

    var pop := _card_menu.create_tween().set_parallel()
    pop.tween_property(_card_menu, "modulate:a", 1.0, OPEN_TIME * 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    pop.tween_property(_card_menu, "scale", Vector2.ONE * CARD_SCALE, OPEN_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
    if _closing:
        return
    if event.is_action_pressed("ui_cancel"):
        _close()
        get_viewport().set_input_as_handled()
        return
    # Right-click closes, mirroring the right-click that opened it. Only on press: the release
    # half of the opening click never reaches us (the overlay is built during the GUI phase,
    # after _input has already been dispatched for that event), and the release of a closing
    # click is filtered by `pressed` here plus the _closing guard above.
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        _close()
        get_viewport().set_input_as_handled()
        return
    if cards.size() > 1:
        if event.is_action_pressed("ui_left"):
            _page(-1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("ui_right"):
            _page(1)
            get_viewport().set_input_as_handled()


func _on_backstop_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _close()


func _close() -> void:
    if _closing:
        return
    _closing = true
    set_process_input(false)
    _backstop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Drop the card's hover tooltips now rather than waiting for its _exit_tree, so they don't
    # hang in the air over the reward screen for the length of the fade.
    _card_menu.clear_hover_tooltips()
    var fade := create_tween().set_parallel()
    fade.tween_property(_backstop, "color:a", 0.0, CLOSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    fade.tween_property(_chrome, "modulate:a", 0.0, CLOSE_TIME * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    fade.chain().tween_callback(_finish_close)


func _finish_close() -> void:
    closed.emit()
    queue_free()
