// based on https://www.seacreaturegame.com/blog/gerstner-waves-with-buoyancy-godot

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_toon;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform float subsurface_scattering_strength : hint_range(0.0, 1.0, 0.01);
uniform sampler2D texture_subsurface_scattering : hint_default_white, filter_nearest_mipmap, repeat_enable;
varying vec3 uv1_triplanar_pos;

uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

//wave stuff derived from:
//https://github.com/stvgale/Gerstner-Waves-Buoyancy-Effects-Godot-4/blob/main/Water.gdshader
uniform vec3 wave_a = vec3(1.0, 0.4, 10.0);
uniform vec2 wave_a_dir = vec2(1.0, 0.0);
uniform vec3 wave_b = vec3(1.0, 0.25, 20.0);
uniform vec2 wave_b_dir = vec2(1.0, 1.0);
uniform vec3 wave_c = vec3(1.0, 0.15, 1.0);
uniform vec2 wave_c_dir = vec2(1.0, 0.5);
const float height_scale = 1.0;
const float frequency_scale = 1.0;
varying vec3 v_normal;
varying float wave_height;

uniform float wave_time;
//wave stuff
vec3 gerstnerWave(vec3 wave, vec2 wave_dir, vec3 p, float t) 
{
    float amplitude = wave.x;
    float steepness = wave.y;
    float wavelength = wave.z;
    float k = (2.0 * PI / wavelength);
    float c = sqrt(9.8 / k);
    vec2 d = normalize(wave_dir);
    float f = k * (dot(d, p.xz) - (c * t));
    float a = (steepness / k);
    return vec3(d.x * (a * cos(f)), amplitude * a * sin(f), d.y * (a * cos(f)));
}

void computeGerstnerNormal(in vec3 wave, in vec2 wave_dir, in vec3 p, float t, inout vec3 tangent, inout vec3 binormal) 
{
    float amplitude = wave.x;
    float steepness = wave.y;
    float wavelength = wave.z;
    float k = 2.0 * PI / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(wave_dir);
    float f = k * (dot(d, p.xz) - (c * t));
    float a = steepness / k;
    tangent += vec3(0.0, 0.0, 0.0);
    binormal += vec3(0.0, 0.0, 0.0);
}

void vertex() {
	// Vertex Color is sRGB: Enabled
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(
				pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
				COLOR.rgb * (1.0 / 12.92),
				lessThan(COLOR.rgb, vec3(0.04045)));
	}

	//wave stuff
    vec3 original_p = (MODEL_MATRIX * vec4(VERTEX.xyz, 1.0)).xyz;
    vec3 displacement = vec3(0.0);
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);

    displacement += gerstnerWave(wave_a, wave_a_dir, original_p, (wave_time / 2.0));
    computeGerstnerNormal(wave_a, wave_a_dir, original_p, (wave_time / 2.0), tangent, binormal);
    
    displacement += gerstnerWave(wave_b, wave_b_dir, original_p, (wave_time / 2.0));
    computeGerstnerNormal(wave_b, wave_b_dir, original_p, (wave_time / 2.0), tangent, binormal);
    
    displacement += gerstnerWave(wave_c, wave_c_dir, original_p, (wave_time / 2.0));
    computeGerstnerNormal(wave_c, wave_c_dir, original_p, (wave_time / 2.0), tangent, binormal);

    VERTEX.y += height_scale * displacement.y;
    vec3 normal = normalize(cross(binormal, tangent));
    wave_height = VERTEX.y;
	
	// UV1 Triplanar: Enabled (with World Triplanar)
	v_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv1_scale + uv1_offset + (TIME * 0.05);
	v_normal /= dot(normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	vec4 albedo_tex = triplanar_texture(texture_albedo, v_normal, uv1_triplanar_pos);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(triplanar_texture(texture_metallic, v_normal, uv1_triplanar_pos), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(triplanar_texture(texture_roughness, v_normal, uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	ALPHA *= albedo.a * albedo_tex.a;

	// Subsurface Scattering: Enabled
	float sss_tex = triplanar_texture(texture_subsurface_scattering, v_normal, uv1_triplanar_pos).r;
	SSS_STRENGTH = subsurface_scattering_strength * sss_tex;
}
