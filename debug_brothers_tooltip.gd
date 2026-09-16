extends Node

# Measures the three Parity Brothers status tooltips against the panel's REAL height budget.
#
# ⚠ MUST be run WINDOWED, never --headless: RichTextLabel content heights are wrong under the
# dummy renderer (measured 246px vs 139px for the same string, 2026-08-27).
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_brothers_tooltip.tscn \
#     --rendering-driver opengl3 --position 2000,2000
#
# The budget is DERIVED from the scene (margin box - its own margins - title height -
# separation) rather than hardcoded, so a future re-layout of the panel moves the assertion
# with it. The panel is fixed-height and clips SILENTLY, which is why this exists.

const TOOLTIP := preload("res://scenes/ui/status_tooltip.tscn")
# brothers_rage was dropped from this list on 2026-09-14: the status is cut from the fight
# (statuses/brothers_rage.gd is orphaned on disk), so measuring a tooltip no player can reach
# would just be a line that fails for the wrong reason the day someone edits the panel.
const CASES := [
    ["res://statuses/parity_odd.tres", "Odd Sensitive"],
    ["res://statuses/parity_even.tres", "Even Sensitive"],
]

var _fail := 0
var _pass := 0


func _ready() -> void:
    await get_tree().process_frame
    var layer := TOOLTIP.instantiate()
    add_child(layer)
    var panel: Panel = layer.get_node("StatusTooltip")
    await get_tree().process_frame

    var margin: MarginContainer = panel.get_node("MarginContainer")
    var title: RichTextLabel = panel.get_node("MarginContainer/VBoxContainer/TooltipTitle")
    var body: RichTextLabel = panel.get_node("MarginContainer/VBoxContainer/TooltipText")
    var vbox: VBoxContainer = panel.get_node("MarginContainer/VBoxContainer")

    var pad: int = margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
    var sep: int = vbox.get_theme_constant("separation")

    print("--- geometry ---")
    print("panel %s  margin box %s  pad %d  sep %d" % [panel.size, margin.size, pad, sep])

    for case in CASES:
        var path: String = case[0]
        var expected_title: String = case[1]
        var st: Status = load(path)
        panel.get_tooltip_content(st)
        await get_tree().process_frame
        await get_tree().process_frame

        var title_h: float = title.get_content_height()
        var body_h: float = body.get_content_height()
        var budget: float = margin.size.y - pad - title_h - sep
        var plain := _strip(body.text)

        print("")
        print("%s  (stacks=%d)" % [st.id, st.stacks])
        print("  title rendered : \"%s\"" % _strip(title.text))
        print("  body           : \"%s\"" % plain)
        print("  chars %d | title_h %.1f | body_h %.1f | budget %.1f" % [
            plain.length(), title_h, body_h, budget])
        _check("%s title is \"%s\"" % [st.id, expected_title],
            _strip(title.text) == expected_title)
        _check("%s body fits (%.1f <= %.1f)" % [st.id, body_h, budget], body_h <= budget)
        _check("%s body is not empty" % st.id, plain.strip_edges() != "")
        _check("%s body states the dial (%d)" % [st.id, st.stacks],
            plain.contains(str(st.stacks)))

    # NEGATIVE CONTROL: a deliberately long body must be caught as overflowing, otherwise the
    # fit assertion above proves nothing.
    var probe := Status.new()
    probe.id = "odd_sensitive"
    probe.stacks = 1
    probe.tooltip = ""
    panel.get_tooltip_content(probe)
    body.text = "[b][center]Every odd face you roll gives this enemy 1 Strength, and this sentence is deliberately padded out so that it wraps onto a fourth line and must be reported as overflowing the fixed-height panel.[/center][/b]"
    await get_tree().process_frame
    await get_tree().process_frame
    var over_h: float = body.get_content_height()
    var over_budget: float = margin.size.y - pad - title.get_content_height() - sep
    print("")
    print("negative control: body_h %.1f vs budget %.1f" % [over_h, over_budget])
    _check("negative control overflows as expected", over_h > over_budget)

    print("")
    print("RESULT: %d passed, %d failed" % [_pass, _fail])
    get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, cond: bool) -> void:
    if cond:
        _pass += 1
        print("  PASS  " + label)
    else:
        _fail += 1
        print("  FAIL  " + label)


func _strip(bb: String) -> String:
    # Manual BBCode strip. A RegEx needs escaped brackets, and getting backslashes through a
    # shell heredoc into a .gd file mangled them into an invalid escape once already, which
    # made this harness HANG (parse error -> _ready never runs -> quit() never called).
    var out := ""
    var depth := 0
    for ch in bb:
        if ch == "[":
            depth += 1
        elif ch == "]":
            if depth > 0:
                depth -= 1
        elif depth == 0:
            out += ch
    return out.strip_edges()
