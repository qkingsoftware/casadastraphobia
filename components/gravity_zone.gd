@tool
extends Area2D

enum PowerMode {
	CONSTANT,
	SWITCH_TOGGLED
}

const DEFAULT_ACTIVE_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const DEFAULT_INACTIVE_TINT: Color = Color(0.6, 0.6, 0.6, 0.4)

@export_group("Dimensions")
@export var zone_size: Vector2 = Vector2(96.0, 96.0):
	set(val):
		var target = val if val != null else Vector2(96.0, 96.0)
		zone_size = Vector2(max(target.x, 16.0), max(target.y, 16.0))
		_rebuild_zone()

@export_group("Visuals (3x3 Texture)")
@export var texture: Texture2D:
	set(val):
		texture = val
		_rebuild_visuals()

@export var patch_margin: int = 16:
	set(val):
		patch_margin = max(val if val != null else 16, 0)
		_rebuild_visuals()

@export_group("Visual Shading")
## Tint color when active / ON
@export var active_tint: Color = DEFAULT_ACTIVE_TINT:
	set(val):
		active_tint = val if val != null else DEFAULT_ACTIVE_TINT
		_update_tint()

## Tint color when deactivated / OFF (clean translucent grey)
@export var inactive_tint: Color = DEFAULT_INACTIVE_TINT:
	set(val):
		inactive_tint = val if val != null else DEFAULT_INACTIVE_TINT
		_update_tint()

@export_group("Control")
@export var enabled: bool = true:
	set(val):
		enabled = val if val != null else true
		_apply_state()

@export var power_mode: PowerMode = PowerMode.CONSTANT:
	set(val):
		power_mode = val if val != null else PowerMode.CONSTANT
		_apply_state()

@export var global_var_name: String = "":
	set(val):
		global_var_name = val.strip_edges() if val != null else ""
		_apply_state()

var is_active: bool = true
var nine_patch: NinePatchRect
var col_shape: CollisionShape2D
var rect_shape: RectangleShape2D
var particles: GPUParticles2D

func _ready() -> void:
	add_to_group("gravityzone")
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	monitoring = true
	monitorable = true

	_setup_nodes()
	_rebuild_zone()
	_apply_state()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if power_mode == PowerMode.SWITCH_TOGGLED and not global_var_name.is_empty():
		var target_state = false
		if Engine.has_meta(global_var_name):
			target_state = bool(Engine.get_meta(global_var_name))
		if target_state != is_active:
			_set_active(target_state)

## Direct bounding check called by Player
func is_point_inside(global_pt: Vector2) -> bool:
	if not is_active or not enabled:
		return false
	
	var local_pt = to_local(global_pt)
	var half_w = zone_size.x * 0.5
	var half_h = zone_size.y * 0.5
	
	return (local_pt.x >= -half_w and local_pt.x <= half_w and 
			local_pt.y >= -half_h and local_pt.y <= half_h)

func _setup_nodes() -> void:
	col_shape = get_node_or_null("CollisionShape2D")
	if not col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		add_child(col_shape)

	if not col_shape.shape is RectangleShape2D:
		rect_shape = RectangleShape2D.new()
		col_shape.shape = rect_shape
	else:
		rect_shape = col_shape.shape as RectangleShape2D

	nine_patch = get_node_or_null("NinePatchRect")
	if not nine_patch:
		nine_patch = NinePatchRect.new()
		nine_patch.name = "NinePatchRect"
		nine_patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(nine_patch)

	particles = get_node_or_null("GPUParticles2D")
	if not particles:
		particles = GPUParticles2D.new()
		particles.name = "GPUParticles2D"
		particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particles.local_coords = true
		add_child(particles)
		particles.texture = _generate_sparkle_texture()

func _rebuild_zone() -> void:
	_setup_nodes()
	_rebuild_collision()
	_rebuild_visuals()
	_rebuild_particles()

func _rebuild_collision() -> void:
	if not rect_shape or not col_shape:
		return
	rect_shape.size = zone_size
	col_shape.position = Vector2.ZERO

func _rebuild_visuals() -> void:
	if not nine_patch:
		return
	nine_patch.texture = texture
	nine_patch.patch_margin_left = patch_margin
	nine_patch.patch_margin_top = patch_margin
	nine_patch.patch_margin_right = patch_margin
	nine_patch.patch_margin_bottom = patch_margin
	nine_patch.size = zone_size
	nine_patch.position = -zone_size * 0.5
	_update_tint()

func _rebuild_particles() -> void:
	if not particles:
		return

	var amount = int(clamp((zone_size.x * zone_size.y) * 0.003, 4, 40))
	particles.amount = amount
	particles.lifetime = 1.6

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(zone_size.x * 0.45, zone_size.y * 0.45, 0.0)
	mat.gravity = Vector3.ZERO
	mat.spread = 0.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0

	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.2, 0.6, 1.0, 0.0))
	gradient.add_point(0.2, Color(0.3, 0.8, 1.0, 0.7))
	gradient.add_point(0.8, Color(0.6, 0.2, 1.0, 0.4))
	gradient.set_color(1, Color(0.6, 0.1, 1.0, 0.0))

	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex
	mat.direction = Vector3(0, -1, 0)

	particles.position = Vector2.ZERO
	particles.process_material = mat
	particles.emitting = is_active and enabled

func _update_tint() -> void:
	if not is_instance_valid(nine_patch):
		return
	
	var is_on: bool = (is_active and enabled)
	var chosen_color: Color = active_tint if is_on else inactive_tint
	
	# Fallback if variable is Nil during inspector load
	if chosen_color == null:
		chosen_color = DEFAULT_ACTIVE_TINT if is_on else DEFAULT_INACTIVE_TINT
		
	nine_patch.modulate = chosen_color

func _set_active(val: bool) -> void:
	is_active = val
	if particles:
		particles.emitting = is_active and enabled
	_update_tint()

func _apply_state() -> void:
	if not enabled:
		_set_active(false)
		return

	match power_mode:
		PowerMode.CONSTANT:
			_set_active(true)
		PowerMode.SWITCH_TOGGLED:
			if not global_var_name.is_empty() and Engine.has_meta(global_var_name):
				_set_active(bool(Engine.get_meta(global_var_name)))
			else:
				_set_active(false)

func _generate_sparkle_texture() -> ImageTexture:
	var img = Image.create(2, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.8))
	return ImageTexture.create_from_image(img)
