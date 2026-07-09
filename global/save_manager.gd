class_name SaveManager
extends RefCounted

# Single-slot run save (v1, designed 2026-07-02, built 2026-07-07). Deliberately scoped to
# map-screen checkpoints only - never mid-combat (see CLAUDE.md "Système de sauvegarde" for
# why mid-fight state is a much bigger chantier). run.gd writes a checkpoint every time the
# player lands back on the map; quitting anywhere else resumes from the last map checkpoint.
#
# Format: a Dictionary serialized with var_to_str (NOT JSON, NOT ResourceSaver):
# - vs JSON: var_to_str round-trips ints as ints (JSON turns every number into a float -
#   silent poison for array indexes like shop_dice_selection) and Vector2 natively (room
#   positions).
# - vs ResourceSaver: no .tres/uid machinery involved at all - this project has a history of
#   Godot rewriting/dropping uid references on hand-made resources (see the Bullseye+ incident
#   in CLAUDE.md), and a save file must never be subject to that. Cards/relics/battles/events
#   are stored as res:// paths (they're all shared, file-backed resources at runtime - verified:
#   the reward screen's cards.duplicate(true) deep-copies the ARRAY, not the Card objects).
# - str_to_var also can't execute code, unlike loading a .tres with embedded scripts.
#
# user:// works on the itch.io web export too (persisted through IndexedDB), so this same
# code covers both desktop and browser builds.

const SAVE_PATH := "user://run_save.save"
const SAVE_VERSION := 1


static func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)


static func write_save(data: Dictionary) -> void:
    data["version"] = SAVE_VERSION
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("SaveManager: could not open %s for writing (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
        return
    file.store_string(var_to_str(data))
    file.close()


# Returns {} if the save is missing, unreadable, or from an incompatible version -
# callers treat an empty dict as "no usable save" and fall back to a fresh run.
static func read_save() -> Dictionary:
    if not has_save():
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("SaveManager: could not open %s for reading (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
        return {}
    var parsed: Variant = str_to_var(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        push_warning("SaveManager: save file is corrupted (not a Dictionary)")
        return {}
    if parsed.get("version", -1) != SAVE_VERSION:
        push_warning("SaveManager: save version %s doesn't match current %d - ignoring old save" % [str(parsed.get("version")), SAVE_VERSION])
        return {}
    return parsed


static func delete_save() -> void:
    if has_save():
        DirAccess.remove_absolute(SAVE_PATH)
