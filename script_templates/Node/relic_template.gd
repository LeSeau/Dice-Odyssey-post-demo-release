extends Relic

var member_var := 0 

func initialize_relic(_owner: RelicUI) -> void:
    print("happens when we gain a relic")

func activate_relic(_owner: RelicUI) -> void:
    print("happens when we activate a relic")
    
func deactivate_relic(_owner: RelicUI) -> void:
    print("happens when we deactivate a relic")
    
func get_tooltip() -> String:
    return tooltip
