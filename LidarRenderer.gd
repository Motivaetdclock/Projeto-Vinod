extends MultiMeshInstance3D

var _mm: MultiMesh

func _ready() -> void:
	print("[LidarRenderer] _ready() called")
	
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.mesh = quad
	_mm.instance_count = 0
	
	multimesh = _mm
	
	print("[LidarRenderer] multimesh set: ", multimesh)
	print("[LidarRenderer] mesh set: ", multimesh.mesh)

func set_points_colored(points: Array) -> void:
	if _mm == null:
		push_error("[LidarRenderer] _mm is null — _ready() did not run")
		return
	
	_mm.instance_count = 0
	_mm.instance_count = points.size()
	
	for i in points.size():
		var entry: Dictionary = points[i]
		_mm.set_instance_transform(i, Transform3D(Basis(), entry.position))
		_mm.set_instance_color(i, entry.color)
