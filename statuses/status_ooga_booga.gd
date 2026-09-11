extends Status

# Display-only badge for the Ooga Booga Blessing. The real effect is
# Global.red_whiff_damage_mult, read by Card.play() when a Red roll misses the socketed card's
# requirement - the same badge/effect split as Trebuchet and Emanation. Deliberately no
# class_name: nothing references this type by class, and skipping it avoids the editor
# class-cache restart dance. Shared by BOTH .tres files, base and "+", which differ only in
# their id and tooltip.


func apply_status(_target: Node) -> void:
    status_applied.emit(self)
