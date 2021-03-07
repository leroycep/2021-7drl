#version 300 es

in highp vec2 uv;
in lowp float frag_opacity;

layout(location = 0) out highp vec4 color;

uniform lowp sampler2D render3D;
// uniform lowp sampler2D render3D_translucent;

void main() {
  color = texture(render3D, uv);
  color.a = min(color.a, frag_opacity);
}
