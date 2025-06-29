// Modified slightly from https://codekokeshi.itch.io/godot-shaders-by-codekokeshi-updating
// Original by CodeKokeshi

// Fish Eye Lens Effect
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 2.25) = 0.4;

void fragment() {
    vec2 uv = SCREEN_UV;

    // Convert UV from (0,1) to (-1,1)
    vec2 scaled_uv = (uv - 0.5) * 2.0;

    // Calculate the distance from center
    float dist = length(scaled_uv);

    // Apply fish eye distortion
    float distortion_factor = 1.0 - distortion_strength * dist;
    vec2 distorted_uv = scaled_uv * distortion_factor;

    // Convert back to (0,1) range
    distorted_uv = (distorted_uv / 2.0) + 0.5;

    // Sample with bounds checking
    vec4 color = vec4(0.0);
    if(distorted_uv.x >= 0.0 && distorted_uv.x <= 1.0 &&
       distorted_uv.y >= 0.0 && distorted_uv.y <= 1.0) {
        color = texture(SCREEN_TEXTURE, distorted_uv);
    }

    COLOR = color;
}