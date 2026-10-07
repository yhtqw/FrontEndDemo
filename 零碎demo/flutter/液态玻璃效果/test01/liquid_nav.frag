#version 320 es
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;

uniform float u_scroll_t;
uniform float u_light_x;
uniform float u_light_y;
uniform float u_is_dark;

out vec4 frag_color;

vec3 blurredColor(vec2 uv, vec2 texel) {
  vec3 color = texture(u_texture, uv).rgb * 0.28;
  color += texture(u_texture, uv + vec2(texel.x, 0.0)).rgb * 0.12;
  color += texture(u_texture, uv - vec2(texel.x, 0.0)).rgb * 0.12;
  color += texture(u_texture, uv + vec2(0.0, texel.y)).rgb * 0.12;
  color += texture(u_texture, uv - vec2(0.0, texel.y)).rgb * 0.12;
  color += texture(u_texture, uv + texel).rgb * 0.06;
  color += texture(u_texture, uv - texel).rgb * 0.06;
  color += texture(u_texture, uv + vec2(texel.x, -texel.y)).rgb * 0.06;
  color += texture(u_texture, uv + vec2(-texel.x, texel.y)).rgb * 0.06;
  return color;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  #ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
  #endif

  vec2 edge = min(uv, 1.0 - uv);
  float edge_distance = min(edge.x, edge.y);
  float rim = 1.0 - smoothstep(0.0, 0.24, edge_distance);

  vec2 from_center = uv - vec2(0.5);
  float center_length = max(length(from_center), 0.001);
  vec2 normal = from_center / center_length;

  float refraction_strength = mix(0.0025, 0.0060, u_scroll_t) * rim;
  vec2 refracted_uv = clamp(uv + normal * refraction_strength, 0.0, 1.0);
  vec2 texel = vec2(2.2) / u_size;
  vec3 base = blurredColor(refracted_uv, texel);

  vec2 dispersion = normal * rim * 0.0012;
  float red = texture(u_texture, clamp(refracted_uv + dispersion, 0.0, 1.0)).r;
  float blue = texture(u_texture, clamp(refracted_uv - dispersion, 0.0, 1.0)).b;
  base = mix(base, vec3(red, base.g, blue), rim * 0.18);

  vec2 light = vec2(u_light_x, u_light_y);
  float light_distance = length(uv - light);
  float moving_highlight = 1.0 - smoothstep(0.06, 0.78, light_distance);
  float specular = pow(rim, 1.55) * (0.12 + moving_highlight * 0.42);

  vec3 light_tint = vec3(0.94, 0.97, 1.0);
  vec3 dark_tint = vec3(0.07, 0.10, 0.15);
  vec3 tint = mix(light_tint, dark_tint, u_is_dark);
  float tint_alpha = mix(0.14, 0.32, u_is_dark);
  vec3 glass = mix(base, tint, tint_alpha);
  glass += mix(light_tint, vec3(0.50, 0.65, 0.92), u_is_dark) * specular;

  frag_color = vec4(clamp(glass, 0.0, 1.0), 1.0);
}
