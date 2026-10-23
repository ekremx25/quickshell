// Liquid Glass fragment shader for the dock background.
// Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
//       -o liquidglass.frag.qsb liquidglass.frag
//
// `source` is the wallpaper region under the glass, expanded by `margin`
// pixels on every side so edge refraction can pull in pixels from outside.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;        // glass size in logical pixels
    float margin;         // extra source pixels on each side
    float radius;         // corner radius
    float refraction;     // max edge displacement in pixels
    float edgeWidth;      // width of the bending rim
    float blurRadius;     // frost blur radius in pixels
    float chroma;         // chromatic split at the rim (0..1)
    float rimLight;       // specular rim strength (0..1)
    float tintStrength;   // how much of `tint` to mix in (0..1)
    vec4 tint;
    vec4 uvBounds;        // valid (on-screen) part of `source`: xy = min, zw = max
    vec2 pointer;         // cursor in item pixels (top-left origin)
    float pointerStrength;// 0 = no droplet, 1 = full droplet
    float pointerRadius;  // droplet radius in pixels
    float shimmer;        // light sweep position: 0 = before start, 1 = past end
};

layout(binding = 1) uniform sampler2D source;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Logical pixel inside the glass (origin at its centre) -> source uv.
vec2 toSourceUv(vec2 p) {
    vec2 full = itemSize + vec2(2.0 * margin);
    return clamp((p + itemSize * 0.5 + vec2(margin)) / full, uvBounds.xy, uvBounds.zw);
}

vec3 frosted(vec2 p, float radius) {
    // Vogel-disk blur: 24 taps spread evenly over a disc.
    const int TAPS = 24;
    vec3 sum = vec3(0.0);
    for (int i = 0; i < TAPS; ++i) {
        float fi = float(i) + 0.5;
        float r = sqrt(fi / float(TAPS)) * radius;
        float a = fi * 2.39996323;
        sum += texture(source, toSourceUv(p + vec2(cos(a), sin(a)) * r)).rgb;
    }
    return sum / float(TAPS);
}

void main() {
    vec2 halfSize = itemSize * 0.5;
    vec2 p = qt_TexCoord0 * itemSize - halfSize;
    float r = min(radius, min(halfSize.x, halfSize.y));
    float d = sdRoundBox(p, halfSize, r);

    // Anti-aliased shape mask.
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    if (alpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Outward surface normal from the SDF gradient.
    vec2 e = vec2(0.5, 0.0);
    vec2 n = vec2(sdRoundBox(p + e.xy, halfSize, r) - sdRoundBox(p - e.xy, halfSize, r),
                  sdRoundBox(p + e.yx, halfSize, r) - sdRoundBox(p - e.yx, halfSize, r));
    n = length(n) > 0.0001 ? normalize(n) : vec2(0.0);

    // 1 at the rim, 0 once deeper than edgeWidth: a convex lens profile.
    float rim = clamp(1.0 + d / edgeWidth, 0.0, 1.0);
    float bend = rim * rim * rim;

    // Pull the background inward near the rim, like light through thick glass.
    vec2 offset = -n * bend * refraction;

    // Droplet under the cursor: a small convex lens that magnifies what is behind it.
    vec2 toPtr = p - (pointer - halfSize);
    float dropDist = length(toPtr);
    float drop = pointerStrength * clamp(1.0 - dropDist / max(pointerRadius, 1.0), 0.0, 1.0);
    float dropShape = drop * drop * (3.0 - 2.0 * drop);
    offset -= toPtr * 0.45 * dropShape;
    // Inside the droplet the frost clears, so the magnified background reads sharp.
    float inDrop = pointerStrength * step(dropDist, pointerRadius);
    vec3 col = frosted(p + offset, blurRadius * (1.0 - 0.85 * max(inDrop * 0.6, dropShape)));

    // Slight colour split where the bend is strongest.
    float split = chroma * bend * refraction * 0.35;
    col.r = mix(col.r, texture(source, toSourceUv(p + offset * (1.0 + split / max(refraction, 0.001)))).r, bend);
    col.b = mix(col.b, texture(source, toSourceUv(p + offset * (1.0 - split / max(refraction, 0.001)))).b, bend);

    // Glass body: a little brighter and more saturated than what is behind it.
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 1.15) * 1.04;
    col = mix(col, tint.rgb, tintStrength);

    // Specular rim lit from the top-left, plus a soft opposite reflection.
    vec2 lightDir = normalize(vec2(-0.55, -0.85));
    float facing = dot(n, lightDir);
    float edgeLine = smoothstep(-2.5, -0.5, d) * (1.0 - smoothstep(-0.5, 0.5, d));
    float spec = rimLight * (bend * 0.35 * max(facing, 0.0) + edgeLine * (0.55 + 0.45 * abs(facing)));
    col += vec3(spec);

    // Droplet rim: a thin bright ring lit from the same direction.
    float ringPos = (dropDist - pointerRadius * 0.92) / max(pointerRadius * 0.09, 0.5);
    float ring = pointerStrength * exp(-ringPos * ringPos);
    vec2 dropN = dropDist > 0.001 ? toPtr / dropDist : vec2(0.0);
    col += vec3(ring * (0.22 + 0.45 * max(dot(dropN, lightDir), 0.0)));
    // A soft glint near the droplet's lit side and a gentle lift inside it.
    col += vec3(0.07 * dropShape);
    float glintD = length(toPtr - lightDir * pointerRadius * 0.45) / (pointerRadius * 0.28);
    col += vec3(0.18 * pointerStrength * exp(-glintD * glintD));

    // Diagonal light sweep travelling left to right.
    float sweepCoord = (p.x + p.y * 0.8) / (itemSize.x + itemSize.y * 0.8) + 0.5;
    float band = (sweepCoord - (shimmer * 1.6 - 0.3)) / 0.07;
    col += vec3(0.20 * exp(-band * band));

    // Gentle inner shade at the bottom edge for depth.
    col *= 1.0 - 0.10 * bend * max(-facing, 0.0);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * alpha * qt_Opacity;
}
