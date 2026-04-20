class_name MyAwesomeStatus
extends Status

var member_var := 0

func initialize_status(target: Node) -> void:
    print("initialize my status for target %s", target)
    
func apply_status(target: Node) -> void:
    print("my status targets %s" % target)
    print("it does %s something" % member_var)
    
    status_applied.emit(self)
