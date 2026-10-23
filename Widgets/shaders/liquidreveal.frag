// Liquid ring reveal used by PopupEntrance: the popup appears inside a circle
// that grows from `origin`; its rim ripples like water, glints, and bends the
// content just inside it. Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
//       -o liquidreveal.frag.qsb liquidreveal.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in pixels
    vec2 origin;      // reveal centre in item pixels
    float radius;     // current reveal radius in pixels
    float wobble;     // rim ripple amplitude in pixels
    float phase;      // ripple animation phase
    float rim;        // rim highlight / lens strength (0..1)
    vec4 rimColor;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 toP = p - origin;
    float d = length(toP);
    float a = atan(toP.y, toP.x);

    // Three travelling ripples give an organic, liquid edge.
    float r = radius + wobble * (0.55 * sin(a * 5.0 + phase)
                               + 0.30 * sin(a * 9.0 - phase * 1.7)
                               + 0.15 * sin(a * 14.0 + phase * 2.3));

    float inside = clamp((r - d) / 1.5 + 0.5, 0.0, 1.0);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Lens just inside the rim: pull content outward a few pixels.
    float band = clamp(1.0 - (r - d) / 22.0, 0.0, 1.0);
    vec2 dir = d > 0.001 ? toP / d : vec2(0.0);
    vec2 uv = (p - dir * band * band * 7.0 * rim) / size;
    vec4 col = texture(source, clamp(uv, vec2(0.0), vec2(1.0)));

    // Bright glint on the rim, only where the popup has content.
    float glint = exp(-pow((r - d) / 2.2, 2.0)) * rim;
    col.rgb += rimColor.rgb * glint * 0.55 * col.a;

    fragColor = col * inside * qt_Opacity;
}
