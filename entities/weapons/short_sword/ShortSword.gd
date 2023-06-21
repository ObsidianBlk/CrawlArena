extends Node3D


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal animation_complete(anim_name)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var d_sides : int = 6:					set = set_d_side
@export var d_count : int = 1:					set = set_d_count
@export var mod : int = 0


# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _anim : AnimationPlayer = $AnimationPlayer


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_d_side(s : int) -> void:
	if s > 0:
		d_sides = s

func set_d_count(c : int) -> void:
	if c > 0:
		d_count = c


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func change_state(state : StringName) -> void:
	match state:
		&"idle":
			_anim.play("idle")
		&"moving":
			_anim.play("move")
		&"attack":
			_anim.play("attack")

func calculate_damage() -> float:
	var dmg : int = 0
	for _i in range(d_count):
		dmg += randi_range(1, d_sides)
	return float(dmg + mod)


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_animation_player_animation_finished(anim_name : String) -> void:
	animation_complete.emit(anim_name)
