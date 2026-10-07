extends ColorRect

@export_color_no_alpha var space_color_1: Color = Color("0a0518") # Deep space purple/black
@export_color_no_alpha var space_color_2: Color = Color("040c20") # Cosmic blue
@export_color_no_alpha var nebula_color: Color = Color("3a1c5d")  # Distant gas cloud
@export var fall_speed: float = 0.2                               # Controls how fast you fall up

@export_group("Pixel Art Settings")
@export var pixel_resolution: Vector2 = Vector2(256, 144)         # The "virtual" resolution of the background
@export var color_depth: int = 8                                  # Limits the number of shades (posterization)

func _ready() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = _get_bg_shader()
	material = mat
	
	_update_shader_params()

func _process(_delta: float) -> void:
	_update_shader_params()

func _update_shader_params() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("color_space1", space_color_1)
		material.set_shader_parameter("color_space2", space_color_2)
		material.set_shader_parameter("color_nebula", nebula_color)
		material.set_shader_parameter("speed", fall_speed)
		material.set_shader_parameter("resolution", pixel_resolution)
		material.set_shader_parameter("color_steps", float(color_depth))

func _get_bg_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;

	uniform vec4 color_space1 : source_color;
	uniform vec4 color_space2 : source_color;
	uniform vec4 color_nebula : source_color;
	uniform float speed = 0.2;
	
	// Pixel art uniforms
	uniform vec2 resolution = vec2(256.0, 144.0);
	uniform float color_steps = 8.0;

	float hash(vec2 p) {
		vec3 p3  = fract(vec3(p.xyx) * .1031);
		p3 += dot(p3, p3.yzx + 33.33);
		return fract((p3.x + p3.y) * p3.z);
	}

	float noise(vec2 p) {
		vec2 i = floor(p);
		vec2 f = fract(p);
		vec2 u = f * f * (3.0 - 2.0 * f);

		return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
		           mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
	}

	void fragment() {
		// 1. Quantize the UVs into a grid to create chunky pixels
		vec2 pixel_uv = floor(UV * resolution) / resolution;
		
		float time_offset = TIME * speed;
		vec2 uv1 = pixel_uv * 2.0;
		uv1.y -= time_offset; 
		float n1 = noise(uv1);
		
		vec2 uv2 = pixel_uv * 4.0;
		uv2.y -= time_offset * 1.4;
		uv2.x += sin(TIME * 0.1) * 0.1;
		float n2 = noise(uv2);
		
		// 2. Posterize the noise to create hard bands of gas rather than smooth gradients
		float nebula_mix = smoothstep(0.2, 0.8, (n1 * 0.6) + (n2 * 0.4));
		nebula_mix = floor(nebula_mix * color_steps) / color_steps;
		
		// 3. Posterize the background gradient
		float gradient_mix = floor(pixel_uv.y * color_steps) / color_steps;
		vec4 base_bg = mix(color_space1, color_space2, gradient_mix);
		
		vec4 final_color = mix(base_bg, color_nebula, nebula_mix * 0.45);
		COLOR = final_color;
	}
	"""
	return shader
