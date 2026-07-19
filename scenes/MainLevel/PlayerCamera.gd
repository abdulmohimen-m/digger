extends Camera2D

@export var shake_decay: float = 30.0 # Strength loss per second
@export var shake_noise: FastNoiseLite

var _shake_strength: float = 0.0
var _noise_x: float = 0.0

func _ready() -> void:
	if not shake_noise:
		shake_noise = FastNoiseLite.new()
		shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		shake_noise.frequency = 0.8
	randomize()
	_noise_x = randf() * 10000.0

func shake(strength: float = 8.0) -> void:
	_shake_strength = strength

func _process(delta: float) -> void:
	if _shake_strength > 0.0:
		_shake_strength = max(0.0, _shake_strength - shake_decay * delta)
		_noise_x += delta * 200.0 # Speed of noise offset change
		
		# Sample noise and scale by current shake strength
		var shake_offset = Vector2(
			shake_noise.get_noise_2d(_noise_x, 0.0),
			shake_noise.get_noise_2d(0.0, _noise_x)
		) * _shake_strength
		
		offset = shake_offset
	else:
		offset = Vector2.ZERO
