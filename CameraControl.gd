extends Camera3D

@export var speed: float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var pitch_limit: float = deg_to_rad(89.0)
@export var circus:Node3D
@export var lidar_range: float = 100.0
@export var horizontal_rays: int = 64
@export var vertical_rays: int = 36
@export var fov_horizontal: float = 90.0
@export var fov_vertical: float = 60.0
@export var scan_interval: float = 0.1  # seconds between full sweeps
@export var point_color: Color = Color(0.1, 1.0, 0.6)
@export var near_color: Color = Color(0.1, 1.0, 0.3)   # green at close range
@export var far_color:  Color = Color(1.0, 0.1, 0.1)   # red at max range
@export var lidar_renderer: MultiMeshInstance3D
@export var root_nd: Node3D
var lidar=false

var _scan_timer: float = 0.0
var _pitch: float = 0.0  # track pitch separately for clamping
func _ensure_collision(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			# Skip if already has a collision body as parent
			if child.get_parent() is CollisionObject3D:
				pass
			else:
				var body := StaticBody3D.new()
				child.get_parent().add_child(body)
				body.global_transform = child.global_transform
				child.reparent(body)
				
				var shape := CollisionShape3D.new()
				shape.shape = child.mesh.create_trimesh_shape()
				body.add_child(shape)
		_ensure_collision(child)
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ensure_collision(root_nd)
	print("renderer: ", lidar_renderer)
	print("multimesh: ", lidar_renderer.multimesh if lidar_renderer else null)
	print("material_override: ", lidar_renderer.material_override if lidar_renderer else null)
	if lidar_renderer == null:
		push_error("LidarRenderer child not found — lidar won't render.")


func _physics_process(delta: float) -> void:
	# --- Movement ---
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis.x * input_dir.x) + (-transform.basis.z * -input_dir.y)
	if direction.length_squared() > 0.0:
		position += direction.normalized() * speed * delta
	
	# --- Lidar (throttled) ---
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		if lidar:
			lidar_scan_and_draw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Yaw (world Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Pitch (local X) with clamp
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -pitch_limit, pitch_limit)
		rotation.x = _pitch
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_F:
			circus.visible=!circus.visible
		if event.pressed and event.keycode == KEY_G:
			lidar=(!lidar)

func lidar_scan_and_draw() -> void:
	if lidar_renderer == null:
		return
	var hits := lidar_scan()          # Array of {position, color}
	lidar_renderer.set_points_colored(hits)

func lidar_scan() -> Array:
	var space_state := get_world_3d().direct_space_state
	var hits: Array = []
	
	# We ARE the camera — use our own basis directly.
	var origin := global_position
	var cam_basis := global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up := cam_basis.y
	
	var half_h := deg_to_rad(fov_horizontal * 0.5)
	var half_v := deg_to_rad(fov_vertical * 0.5)
	
	for y in vertical_rays:
		for x in horizontal_rays:
			var nx := (float(x) / (horizontal_rays - 1)) * 2.0 - 1.0
			var ny := (float(y) / (vertical_rays - 1)) * 2.0 - 1.0
			
			var yaw := nx * half_h
			var pitch := ny * half_v
			
			var dir := (forward + right * tan(yaw) + up * tan(pitch)).normalized()
			var to := origin + dir * lidar_range
			
			var query := PhysicsRayQueryParameters3D.create(origin, to)
			query.exclude = [self]
			# Use the camera's own collision layer as mask if you want,
			# or set a specific layer for lidar targets:
			# query.collision_mask = 1
			
			var result := space_state.intersect_ray(query)
			if not result.is_empty():
				var hit_pos: Vector3 = result.position
				var t: float = clamp(hit_pos.distance_to(origin) / lidar_range, 0.0, 1.0)
				var col: Color = near_color.lerp(far_color, t)
				hits.append({position = hit_pos, color = col})			
	
	return hits
