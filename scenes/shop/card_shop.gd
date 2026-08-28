class_name Shop
extends Control

const SHOP_CARD = preload("res://scenes/shop/shop_card.tscn")
const SHOP_RELIC = preload("res://scenes/shop/shop_relic.tscn")
const SHOP_MUSIC = preload("res://taverna_mystica.mp3")

@export var shop_relic_pool: RelicPool
@export var char_stats: CharacterStats
@export var run_stats: RunStats
@export var relic_handler: RelicHandler

@onready var cards: HBoxContainer = %Cards
@onready var relics: HBoxContainer = %Relics
@onready var deal_stall: Control = %DealStall
@onready var deal_title: Label = %DealTitle
@onready var deal_die_texture: TextureRect = %DealDieTexture
@onready var deal_buy_label: RichTextLabel = %DealBuyLabel
@onready var remove_stall: Control = %RemoveStall
@onready var card_fan: Control = %CardFan
@onready var remove_card_label: RichTextLabel = %RemoveCardLabel

# Card removal service - one per shop visit, priced off a run-scoped counter so it
# escalates across the run like STS purges (50, 75, 100...). Global.card_removals_bought
# is reset in reset_run_state() and saved/restored by run.gd.
const CARD_REMOVAL_BASE_PRICE := 50
const CARD_REMOVAL_PRICE_STEP := 25

const DICE_TOOLTIP_SCENE := preload("res://scenes/ui/dice_tooltip.tscn")

# Deal die: shown-face art per type - the same textures the dice shop's columns use
# (keep in sync with dice_shop.tscn if those ever change).
const DICE_DEAL_TEXTURES := {
    "evil": "res://assets/images/evil6.png",
    "giant": "res://assets/images/giant12.png",
    "magma": "res://assets/images/magma6.png",
    "even": "res://assets/images/even8.png",
    "odd": "res://assets/images/odd7.png",
    "blue": "res://assets/images/blue6.png",
    "red": "res://assets/images/red6.png",
    "green": "res://assets/images/green1.png",
    "mech": "res://assets/images/mech6.png",
}
const DEAL_GREEN := "#5CD95C"  # same green as upgraded card titles
const DEAL_GREEN_COL := Color("5CD95C")
const RED_COL := Color("FF4444")
const GOLD_COL := Color("FFD700")
const COIN_TEXTURE := preload("res://gold_icon_v2.png")
# Baseline-calibrated LuckiestGuy for price digits (see shop.gd's PRICE_FONT note).
const PRICE_FONT := preload("res://fonts/luckiest_guy_numbers.tres")

# Shared soft radial texture + additive material for the deal-die halo - same recipe as
# the dice infusion screen (dice_infusion.gd::_get_glow_texture / _get_additive_material),
# duplicated here because those are that scene's own statics. This is the "infused"-style
# glow Julien asked for (soft breathing halo), NOT the combat aura shader.
static var _glow_texture: GradientTexture2D
static var _additive_material: CanvasItemMaterial

var removal_used_this_visit := false
# Armed when the removal slot is clicked, consumed when a card is actually removed.
# Backing out of the deck view never emits card_removed, so cancelling costs nothing -
# the flag just stays armed until the slot is clicked again.
var _removal_pending := false

var _deal_type := ""
var _deal_full_price := 0
var _deal_price := 0
var _deal_sold := false
var _dice_tooltip: Node = null
var _deal_glow: TextureRect = null
var _deal_glow_pulse: Tween = null
var _deal_mote_timer: Timer = null
var _deal_accent := Color.WHITE

# Sprite coin-row pieces (replace the old bbcode labels so the coin is a real sized image
# snug against the number, matching the card/relic/dice-shop rows).
var _deal_row: HBoxContainer = null
var _deal_struck: RichTextLabel = null
var _deal_num: Label = null
var _removal_row: HBoxContainer = null
var _removal_num: Label = null


func _make_coin(px: int) -> TextureRect:
    var coin := TextureRect.new()
    coin.texture = COIN_TEXTURE
    coin.custom_minimum_size = Vector2(px, px)
    coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return coin


func _make_num(px: int) -> Label:
    var l := Label.new()
    l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_override("font", PRICE_FONT)
    l.add_theme_font_size_override("font_size", px)
    l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.01))
    l.add_theme_constant_override("outline_size", 4)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _ready() -> void:
    for shop_card: ShopCard in cards.get_children():
        shop_card.queue_free()

    for shop_relic: ShopRelic in relics.get_children():
        shop_relic.queue_free()

    Events.shop_card_bought.connect(_on_shop_card_bought)
    Events.shop_relic_bought.connect(_on_shop_relic_bought)
    Events.card_removed.connect(_on_removal_card_removed)

    # Card shop gets its own theme; the dice shop (a TopBar overlay, never this
    # scene) stays on whatever's already playing. Map music resumes in _exit_tree()
    # regardless of which button/path freed this node.
    Events.stop_map_music.emit()
    MusicPlayer.play(SHOP_MUSIC, true)


func populate_shop() -> void:
    _generate_shop_cards()
    _generate_shop_relics()
    _setup_deal_stall()
    _setup_removal_stall()

# STS2's merchant rolls every slot independently instead of guaranteeing a composition
# (CardFactory.CreateForMerchant -> CardRarityOdds.RollWithoutChangingFutureOdds(Shop)):
# 0.54 / 0.37 / 0.09 plus the run's current rare offset. Two consequences worth knowing:
#   * It READS the offset but never advances it, so browsing a shop can no longer starve
#     the next combat reward (and a dry spell makes shop rares likelier too).
#   * A shop is no longer guaranteed to hold a Rare. The old SHOP_COMPOSITION hard-wired
#     exactly one per visit; measured, ~18% of visits hold one at the run-start offset
#     (0.09 - 0.05 = 4% a slot), climbing as a dry spell pushes the offset up.
const SHOP_CARD_SLOTS := 5


func _generate_shop_cards() -> void:
    var shop_card_array: Array[Card] = []
    var available_cards: Array[Card] = char_stats.draftable_cards.cards.duplicate(true)
    var owned_cards: Array[Card] = char_stats.deck.cards
    # run_stats is assigned by run.gd::_on_shop_entered before populate_shop(); the fallback
    # only covers a shop booted straight from the editor with nothing wired up.
    var offset := RunStats.RARE_OFFSET_FLOOR
    if run_stats:
        offset = run_stats.rare_offset

    for _slot in SHOP_CARD_SLOTS:
        var tier := CardRarityDraw.roll_rarity(CardRarityDraw.Source.SHOP, offset)
        var picked_card := CardRarityDraw.pick_card(available_cards, tier, owned_cards)
        if picked_card:
            available_cards.erase(picked_card)
            shop_card_array.append(picked_card)

    for card: Card in shop_card_array:
        var new_shop_card := SHOP_CARD.instantiate() as ShopCard
        cards.add_child(new_shop_card)
        new_shop_card.card = card
        new_shop_card.update(run_stats)


func _generate_shop_relics() -> void:
    # Rarity-weighted, and the ONLY draw that can surface shop-exclusive relics. Drawn one at
    # a time with the running list as the exclude set, so the three slots can't duplicate.
    var shop_relics_array: Array[Relic] = []
    for _slot in 3:
        var relic := shop_relic_pool.get_random_shop_relic(
                char_stats, relic_handler, shop_relics_array)
        if relic == null:
            break  # pool exhausted (tiny pool, or the player owns nearly everything)
        shop_relics_array.append(relic)

    for relic: Relic in shop_relics_array:
        var new_shop_relic := SHOP_RELIC.instantiate() as ShopRelic
        relics.add_child(new_shop_relic)
        new_shop_relic.relic = relic
        new_shop_relic.update(run_stats)


func _update_items() -> void:
    for shop_card: ShopCard in cards.get_children():
        shop_card.update(run_stats)

    for shop_relic: ShopRelic in relics.get_children():
        shop_relic.update(run_stats)

    _update_removal_price()
    _update_deal_price()


# --- Deal die: one discounted die (-20%), always a type the dice shop does NOT
# currently offer - "oh, actually that might work" fuel. Click the die to buy; consumed
# on purchase, the next card shop visit re-picks a fresh one. ---

func _setup_deal_stall() -> void:
    # The dice-shop selection may not exist yet if this room is the first shop the
    # player sees this run - whichever shop opens first initializes the shared state.
    Global.ensure_dice_shop_state()
    # -1 = bought earlier (or pre-rework save): re-pick so every visit has one deal.
    if Global.shop_dice_deal_index < 0:
        Global.shop_dice_deal_index = Global.pick_dice_deal_index()

    _deal_type = Global.DICE_TYPE_ORDER[Global.shop_dice_deal_index]
    _deal_full_price = Global.current_dice_price(_deal_type)
    _deal_price = int(_deal_full_price * Global.DICE_DEAL_DISCOUNT)

    deal_title.text = KeywordColorizer.dice_display_name(_deal_type) + " Dice"
    deal_title.add_theme_color_override("font_color", DicePalette.accent(_deal_type))
    deal_die_texture.texture = load(DICE_DEAL_TEXTURES[_deal_type])
    _setup_deal_glow()
    _build_deal_badge()
    _build_deal_row()
    _update_deal_price()

    # Click anywhere in the stall to buy (die art is mouse-PASS so its own tooltip/hover
    # still fire while the click falls through to the stall).
    deal_stall.gui_input.connect(_on_deal_stall_gui_input)
    deal_die_texture.mouse_entered.connect(_on_deal_die_mouse_entered)
    deal_die_texture.mouse_exited.connect(_on_deal_die_mouse_exited)


# Infusion-style treatment (Julien: "the small orbs rising to the top, like the dice
# infusion screen"): a SMALL soft halo behind the die + a steady stream of rising accent
# motes over it. Recipe copied from dice_infusion.gd. Built in code inside the stall.
const DEAL_MOTE_INTERVAL := 0.27  # single die, own timer; bumped from 0.35

func _setup_deal_glow() -> void:
    _deal_accent = DicePalette.accent(_deal_type)
    # Small breathing halo behind the die (kept subtle - the motes are the main effect).
    _deal_glow = TextureRect.new()
    # Shaped halo (rounded square, follows the die silhouette) - same swap as the dice shop
    # and infusion screen; the radial circle behind a square die read as shape-blind. The
    # deal motes keep the radial texture.
    _deal_glow.texture = DicePalette.die_halo_texture()
    _deal_glow.material = _get_additive_material()
    _deal_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _deal_glow.stretch_mode = TextureRect.STRETCH_SCALE
    _deal_glow.size = Vector2(166, 166)
    # Centered on the die art (offset 42-158 / 60-176 in stall space -> center 100,118).
    _deal_glow.position = Vector2(100, 118) - _deal_glow.size / 2.0
    _deal_glow.pivot_offset = _deal_glow.size / 2.0
    _deal_glow.modulate = Color(_deal_accent.r, _deal_accent.g, _deal_accent.b, 0.35)
    _deal_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deal_stall.add_child(_deal_glow)
    deal_stall.move_child(_deal_glow, 1)  # behind the die art

    _deal_glow_pulse = create_tween().set_loops()
    _deal_glow_pulse.tween_property(_deal_glow, "scale", Vector2(1.06, 1.06), 1.6) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _deal_glow_pulse.parallel().tween_property(_deal_glow, "modulate:a", 0.45, 1.6)
    _deal_glow_pulse.tween_property(_deal_glow, "scale", Vector2(0.94, 0.94), 1.6) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _deal_glow_pulse.parallel().tween_property(_deal_glow, "modulate:a", 0.28, 1.6)

    # Rising accent motes - "power seeping off the die".
    _deal_mote_timer = Timer.new()
    _deal_mote_timer.wait_time = DEAL_MOTE_INTERVAL
    _deal_mote_timer.autostart = true
    _deal_mote_timer.timeout.connect(_spawn_deal_mote)
    deal_stall.add_child(_deal_mote_timer)


func _spawn_deal_mote() -> void:
    if _deal_sold:
        return
    var mote := TextureRect.new()
    mote.texture = _get_glow_texture()
    mote.material = _get_additive_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    var mote_size := randf_range(10.0, 20.0)
    mote.size = Vector2(mote_size, mote_size)
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.modulate = Color(_deal_accent.r, _deal_accent.g, _deal_accent.b, 0.0)
    # Start low over the die art (x 45-155, y near the die's bottom) and rise.
    mote.position = Vector2(randf_range(48.0, 152.0 - mote_size), randf_range(150.0, 180.0))
    deal_stall.add_child(mote)

    var rise := randf_range(70.0, 110.0)
    var duration := randf_range(1.1, 1.7)
    var peak_alpha := randf_range(0.46, 0.78)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(mote, "position:y", mote.position.y - rise, duration) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(mote, "position:x", mote.position.x + randf_range(-16.0, 16.0), duration)
    t.tween_property(mote, "modulate:a", peak_alpha, duration * 0.3)
    t.tween_property(mote, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
    t.chain().tween_callback(mote.queue_free)


# Small "-20%" tag pinned to the top-right of the die art, built in code (single use,
# not worth a .tscn sub_resource).
func _build_deal_badge() -> void:
    var badge := Panel.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.16, 0.09, 0.95)
    style.border_color = Color(DEAL_GREEN)
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    badge.add_theme_stylebox_override("panel", style)
    badge.size = Vector2(64, 28)
    # Sits ON the die art's top-right corner (sale-sticker style).
    badge.position = Vector2(58, 4)
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var label := Label.new()
    label.text = "-20%"
    label.add_theme_color_override("font_color", Color(DEAL_GREEN))
    label.add_theme_color_override("font_outline_color", Color(0.03, 0.1, 0.05))
    label.add_theme_constant_override("outline_size", 2)
    label.add_theme_font_override("font", preload("res://Belwe Bold/Belwe Bold.otf"))
    label.add_theme_font_size_override("font_size", 16)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.add_child(label)

    deal_die_texture.add_child(badge)


# Row: [struck full price][spacer][coin][deal price]. Positioned over the (hidden) bbcode
# DealBuyLabel, which is reused only for the "Sold!" state.
func _build_deal_row() -> void:
    deal_buy_label.hide()
    _deal_row = HBoxContainer.new()
    _deal_row.position = Vector2(12, 190)
    _deal_row.size = Vector2(176, 42)
    _deal_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _deal_row.add_theme_constant_override("separation", 0)
    _deal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _deal_struck = RichTextLabel.new()
    _deal_struck.bbcode_enabled = true
    _deal_struck.fit_content = true
    _deal_struck.autowrap_mode = TextServer.AUTOWRAP_OFF  # else it collapses to 0 width in the HBox
    _deal_struck.scroll_active = false
    _deal_struck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _deal_struck.add_theme_font_override("normal_font", PRICE_FONT)
    _deal_struck.add_theme_font_size_override("normal_font_size", 18)
    _deal_struck.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _deal_row.add_child(_deal_struck)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(8, 0)
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _deal_row.add_child(spacer)

    _deal_row.add_child(_make_coin(24))
    _deal_num = _make_num(20)
    _deal_row.add_child(_deal_num)
    deal_stall.add_child(_deal_row)


func _update_deal_price() -> void:
    if not deal_buy_label:
        return
    if _deal_sold:
        if _deal_row:
            _deal_row.hide()
        deal_buy_label.show()
        deal_buy_label.text = "[center][font_size=18]Sold![/font_size][/center]"
        return
    # Struck full price (grey) + coin + deal price (green / red if unaffordable).
    _deal_struck.text = "[s][color=#AAAAAA]" + str(_deal_full_price) + "[/color][/s]"
    _deal_num.text = str(_deal_price)
    _deal_num.add_theme_color_override("font_color",
            DEAL_GREEN_COL if Global.gold >= _deal_price else RED_COL)


func _on_deal_stall_gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    if _deal_sold or Global.gold < _deal_price:
        return
    _deal_sold = true
    Global.gold -= _deal_price
    SFXPlayer.play(load("res://sounds/buydicesound.wav"))
    AchievementManager.unlock("customer")
    AchievementManager.add_stat("dice_bought_from_shop", 1)
    # Same bookkeeping as the dice shop's buy handlers (max + current + inventory +
    # purchased counts, so future dice prices escalate off this purchase too).
    Global.set(_deal_type + "_dice_max_amount", Global.get(_deal_type + "_dice_max_amount") + 1)
    Global.set(_deal_type + "_dice_current_amount", Global.get(_deal_type + "_dice_current_amount") + 1)
    if not Global.dice_inventory.has(_deal_type):
        Global.dice_inventory.append(_deal_type)
    Global.purchased_dice_counts[_deal_type] += 1
    # Consumed - the next card shop visit re-picks a fresh deal (see _setup_deal_stall).
    Global.shop_dice_deal_index = -1
    Events.dice_bought.emit(_deal_type)
    Events.update_dice_top_bar.emit()
    Events.gold_changed.emit()
    # If a dice-shop panel happens to be alive, its prices must reflect the escalation
    # this purchase just caused (it listens to this signal; no listener = harmless).
    Events.dice_price_changed.emit()
    deal_die_texture.modulate = Color(0.5, 0.5, 0.5)
    if _deal_glow_pulse and _deal_glow_pulse.is_valid():
        _deal_glow_pulse.kill()
    if _deal_glow and is_instance_valid(_deal_glow):
        _deal_glow.hide()
    if _deal_mote_timer and is_instance_valid(_deal_mote_timer):
        _deal_mote_timer.stop()
    _update_items()


# Subtle hover pop on the die (its own affordance since the stall is one big click target).
func _on_deal_die_mouse_entered() -> void:
    if not _deal_sold:
        create_tween().tween_property(deal_die_texture, "scale", Vector2(1.08, 1.08), 0.1)
    _show_dice_tooltip()


func _on_deal_die_mouse_exited() -> void:
    create_tween().tween_property(deal_die_texture, "scale", Vector2.ONE, 0.1)
    _cleanup_dice_tooltip()


# Same hover tooltip as the dice shop's columns, spawned left of the stall (the stall
# hugs the right screen edge). Same leak guards as shop.gd: cleanup on exit AND on
# _exit_tree (leaving the room mid-hover never fires mouse_exited).
func _show_dice_tooltip() -> void:
    _cleanup_dice_tooltip()
    _dice_tooltip = DICE_TOOLTIP_SCENE.instantiate()
    Global.add_tooltip(_dice_tooltip, self)
    var tooltip_panel = _dice_tooltip.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content(_deal_type)
    tooltip_panel.show_tooltip(Vector2(810, 180))


func _cleanup_dice_tooltip() -> void:
    if _dice_tooltip and is_instance_valid(_dice_tooltip):
        _dice_tooltip.queue_free()
    _dice_tooltip = null


func _exit_tree() -> void:
    _cleanup_dice_tooltip()
    MusicPlayer.stop()
    Events.start_map_music.emit()


# --- Card removal: click the card-fan to open the deck view and purge a card. ---

func _setup_removal_stall() -> void:
    # Sprite coin row over the (hidden) bbcode RemoveCardLabel, reused only for "Removed!".
    remove_card_label.hide()
    _removal_row = HBoxContainer.new()
    _removal_row.position = Vector2(12, 150)
    _removal_row.size = Vector2(176, 42)
    _removal_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _removal_row.add_theme_constant_override("separation", 0)
    _removal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _removal_row.add_child(_make_coin(26))
    _removal_num = _make_num(21)
    _removal_row.add_child(_removal_num)
    remove_stall.add_child(_removal_row)

    _update_removal_price()
    remove_stall.gui_input.connect(_on_remove_stall_gui_input)
    remove_stall.mouse_entered.connect(_on_remove_stall_mouse_entered)
    remove_stall.mouse_exited.connect(_on_remove_stall_mouse_exited)


func _removal_price() -> int:
    return CARD_REMOVAL_BASE_PRICE + CARD_REMOVAL_PRICE_STEP * Global.card_removals_bought


func _update_removal_price() -> void:
    if not remove_card_label:
        return
    if removal_used_this_visit:
        if _removal_row:
            _removal_row.hide()
        remove_card_label.show()
        remove_card_label.text = "[center][font_size=20]Removed![/font_size][/center]"
        return
    var removal_price := _removal_price()
    _removal_num.text = str(removal_price)
    # Explicit type: Global.gold is untyped, so := can't infer across the comparison.
    var affordable: bool = Global.gold >= removal_price
    _removal_num.add_theme_color_override("font_color", GOLD_COL if affordable else RED_COL)


func _on_remove_stall_gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    if removal_used_this_visit or _removal_pending or Global.gold < _removal_price():
        return
    _removal_pending = true
    # Same flow the removal events use: run.gd sets Global.removing_card and opens the
    # deck view; picking a card there emits Events.card_removed (handled below).
    Events.open_deck_view.emit()


func _on_remove_stall_mouse_entered() -> void:
    if removal_used_this_visit:
        return
    create_tween().tween_property(card_fan, "scale", Vector2(1.06, 1.06), 0.1)


func _on_remove_stall_mouse_exited() -> void:
    create_tween().tween_property(card_fan, "scale", Vector2.ONE, 0.1)


func _on_removal_card_removed(_card) -> void:
    if not _removal_pending:
        return
    _removal_pending = false
    Global.gold -= _removal_price()
    Global.card_removals_bought += 1
    removal_used_this_visit = true
    SFXPlayer.play(load("res://sounds/buydicesound.wav"))
    card_fan.modulate = Color(0.5, 0.5, 0.5)
    Events.gold_changed.emit()
    _update_items()


func _on_back_button_pressed() -> void:
    Events.shop_exited.emit()


func _on_shop_card_bought(card: Card, gold_cost: int) -> void:
    char_stats.deck.add_card(card)
    Global.gold -= gold_cost
    _update_items()
    Events.gold_changed.emit()


func _on_shop_relic_bought(relic: Relic, gold_cost: int) -> void:
    relic_handler.add_relic(relic)
    Global.gold -= gold_cost
    _update_items()
    Events.gold_changed.emit()


func _on_button_pressed() -> void:
    Events.shop_exited.emit()


static func _get_glow_texture() -> Texture2D:
    if _glow_texture == null:
        var gradient := Gradient.new()
        gradient.set_color(0, Color(1, 1, 1, 1))
        gradient.set_color(1, Color(1, 1, 1, 0))
        gradient.add_point(0.55, Color(1, 1, 1, 0.35))
        var tex := GradientTexture2D.new()
        tex.gradient = gradient
        tex.fill = GradientTexture2D.FILL_RADIAL
        tex.fill_from = Vector2(0.5, 0.5)
        tex.fill_to = Vector2(0.5, 0.0)
        tex.width = 256
        tex.height = 256
        _glow_texture = tex
    return _glow_texture


static func _get_additive_material() -> CanvasItemMaterial:
    if _additive_material == null:
        var mat := CanvasItemMaterial.new()
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        _additive_material = mat
    return _additive_material
