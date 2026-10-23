// Genie entrance used by PopupEntrance: the popup pours out of the edge it
// opens from, narrow like a funnel at first and widening as it lands.
// Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
//       -o genie.frag.qsb genie.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in pixels
    vec2 origin;      // funnel mouth in item pixels
    float progress;   // 0 = hidden, 1 = fully open
    float side;       // edge it opens from: 0 top, 1 bottom, 2 left, 3 right
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 o = origin / size;

    // Rotate the problem so the popup always pours "down" from a top edge:
    // a = distance from the opening edge, c = position across it.
    float a = uv.y, c = uv.x, oc = o.x;
    if (side > 0.5 && side < 1.5) { a = 1.0 - uv.y; }
    else if (side > 1.5 && side < 2.5) { a = uv.x; c = uv.y; oc = o.y; }
    else if (side > 2.5) { a = 1.0 - uv.x; c = uv.y; oc = o.y; }

    // Rows further from the mouth open later, so the shape stays funnel-like.
    float local = clamp(progress * 1.7 - a * 0.7, 0.0, 1.0);
    float ease = local * local * (3.0 - 2.0 * local);
    float width = mix(0.04, 1.0, ease);
    float sc = oc + (c - oc) / width;

    // The body slides out of the mouth while stretching to full length.
    float reach = 1.0 - pow(1.0 - progress, 3.0);
    float sa = a / max(reach, 0.001);

    float inside = step(0.0, sc) * step(sc, 1.0) * step(sa, 1.0);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 src = vec2(sc, sa);
    if (side > 0.5 && side < 1.5) src = vec2(sc, 1.0 - sa);
    else if (side > 1.5 && side < 2.5) src = vec2(sa, sc);
    else if (side > 2.5) src = vec2(1.0 - sa, sc);

    fragColor = texture(source, src) * qt_Opacity * smoothstep(0.0, 0.25, progress);
}
