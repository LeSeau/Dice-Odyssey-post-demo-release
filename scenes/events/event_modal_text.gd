# RichTextLabel has no vertical_alignment (unlike Label), so a BBCode label
# anchored inside a fixed-height band always hugs the top of it - which is why
# the event mini-game panels read as top-heavy (the "Rewards:" band was 15px
# out, the reward chips 4px).
#
# center_labels() walks a modal and re-centres every RichTextLabel against its
# own measured content height, so it keeps working if the text, the font or the
# line count changes. Deliberately NO class_name: consumers preload() it, so the
# editor's script class cache never has to be rebuilt for it.
extends RefCounted

const BASE_OFFSETS_META := "modal_text_base_offsets"


# Re-centre one label. Safe to call repeatedly - the untouched offsets are
# stashed on first use, so a second call re-centres from the original box
# instead of stacking another shift on top of the last one.
static func center_label(label: RichTextLabel) -> void:
    if label == null or not is_instance_valid(label):
        return

    if not label.has_meta(BASE_OFFSETS_META):
        label.set_meta(BASE_OFFSETS_META, Vector2(label.offset_top, label.offset_bottom))
    var base: Vector2 = label.get_meta(BASE_OFFSETS_META)

    # Derive the band height from the anchors rather than from label.size, which
    # is a frame behind right after the offsets are written.
    var parent_control := label.get_parent() as Control
    if parent_control == null:
        return
    var box_height := parent_control.size.y * (label.anchor_bottom - label.anchor_top) \
        + (base.y - base.x)
    if box_height <= 0.0:
        return

    var content_height := float(label.get_content_height())
    if content_height <= 0.0 or content_height >= box_height:
        # taller than its band: leave it top-aligned so nothing is clipped
        label.offset_top = base.x
        label.offset_bottom = base.y
        return

    var shift := floorf((box_height - content_height) * 0.5)
    label.offset_top = base.x + shift
    label.offset_bottom = base.y + shift


static func center_labels(root: Node) -> void:
    if root == null or not is_instance_valid(root):
        return
    if root is RichTextLabel:
        center_label(root)
    for child in root.get_children():
        center_labels(child)
