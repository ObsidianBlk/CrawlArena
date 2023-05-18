extends Control
class_name UIMenu


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action_name, payload)


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func send_action_request(action_name : StringName, payload : Variant = null) -> void:
	action_requested.emit(action_name, payload)
