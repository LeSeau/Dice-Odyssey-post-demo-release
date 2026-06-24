class_name BlockEffect
extends Effect

const BLOCK_POPUP_SCENE := preload("res://scenes/ui/block_popup.tscn")

var amount := 0


func execute(targets: Array[Node]) -> void:
    for target in targets:
        if not target:
            continue
        if target is Enemy or target is Player:
            target.stats.block += amount
            SFXPlayer.play(sound)

            var block_popup = BLOCK_POPUP_SCENE.instantiate()
            target.get_parent().add_child(block_popup)
            block_popup.global_position = target.global_position
            block_popup.show_block(amount)
