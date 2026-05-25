extends Node3D

var _base_y: float
var _time: float = 0.0

func _ready() -> void:
	_base_y = position.y

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.5) * 0.25
	rotate_y(delta * 0.8)
