.pragma library

function rgb(value) {
    var match = /^#([0-9a-f]{6})$/i.exec(String(value));
    if (!match) return null;
    return [parseInt(match[1].slice(0, 2), 16) / 255,
            parseInt(match[1].slice(2, 4), 16) / 255,
            parseInt(match[1].slice(4, 6), 16) / 255];
}
function hex(channels) {
    return "#" + channels.map(function(v) {
        var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
        return s.length === 1 ? "0" + s : s;
    }).join("");
}
function luminance(c) {
    var linear = c.map(function(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}
function contrast(a, b) {
    var x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function hsl(c) {
    var max = Math.max.apply(null, c), min = Math.min.apply(null, c);
    var delta = max - min, lightness = (max + min) / 2;
    if (delta === 0) return [0, 0, lightness];
    var saturation = delta / (1 - Math.abs(2 * lightness - 1));
    var hue = max === c[0] ? ((c[1] - c[2]) / delta) % 6
        : max === c[1] ? (c[2] - c[0]) / delta + 2 : (c[0] - c[1]) / delta + 4;
    return [(hue * 60 + 360) % 360, saturation, lightness];
}
function fromHsl(hue, saturation, lightness) {
    var chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
    var x = chroma * (1 - Math.abs((hue / 60) % 2 - 1));
    var m = lightness - chroma / 2;
    var c = hue < 60 ? [chroma, x, 0] : hue < 120 ? [x, chroma, 0]
        : hue < 180 ? [0, chroma, x] : hue < 240 ? [0, x, chroma]
        : hue < 300 ? [x, 0, chroma] : [chroma, 0, x];
    return c.map(function(v) { return v + m; });
}
// Move along the image hue's lightness axis, instead of mixing in white
// (which washed saturated greens/blues into gray pastels). Chromatic image
// samples get a modest saturation boost; neutral images remain neutral.
function readable(sample, background) {
    var c = rgb(sample), bg = rgb(background);
    if (!c || !bg) return sample;
    var tone = hsl(c);
    if (tone[1] > 0.12) tone[1] = Math.min(0.90, Math.max(0.58, tone[1] * 1.25));
    var darkPanel = luminance(bg) < 0.18;
    var ink = darkPanel ? rgb("#080a0d") : [1, 1, 1];
    function at(lightness) { return fromHsl(tone[0], tone[1], lightness); }
    function readableAt(lightness) {
        var candidate = at(lightness);
        return contrast(candidate, bg) >= 4.6 && contrast(candidate, ink) >= 7.2;
    }
    var start = Math.max(0.18, Math.min(0.72, tone[2]));
    if (readableAt(start)) return hex(at(start));
    var low = 0, high = 1, target = darkPanel ? 1 : 0;
    for (var i = 0; i < 24; i++) {
        var mix = (low + high) / 2;
        if (readableAt(start + (target - start) * mix)) high = mix;
        else low = mix;
    }
    return hex(at(start + (target - start) * high));
}
function accents(samples, background, fallback) {
    var result = [];
    for (var i = 0; samples && i < samples.length; i++) {
        if (!rgb(samples[i])) continue;
        var color = readable(samples[i], background), channels = rgb(color);
        var distinct = result.every(function(previous) {
            var old = rgb(previous);
            return Math.sqrt(channels.reduce(function(sum, v, n) { return sum + Math.pow(v - old[n], 2); }, 0)) > 0.18;
        });
        if (distinct) result.push(color);
        if (result.length === 6) break;
    }
    // Uniform images retain their own hue instead of inventing other accents.
    if (result.length === 0) return fallback.slice();
    var available = result.slice();
    while (result.length < 6) result.push(available[result.length % available.length]);
    return result;
}

// Keep neutral surfaces in the dominant image hue too. Otherwise a small
// saturated object selected by matugen can tint an otherwise blue/green scene.
function surfaces(samples, light) {
    if (!samples || !samples.length || !rgb(samples[0])) return null;
    var dominant = rgb(samples[0]);
    function tint(neutral, amount) {
        return hex(dominant.map(function(v) { return neutral * (1 - amount) + v * amount; }));
    }
    return light ? {
        background: tint(1, 0.06), panel: tint(0.97, 0.10), raised: tint(0.94, 0.13),
        variant: tint(0.85, 0.16), text: tint(0.04, 0.10), subtext: tint(0.25, 0.10)
    } : {
        background: tint(0.04, 0.18), panel: tint(0.085, 0.20), raised: tint(0.13, 0.20),
        variant: tint(0.22, 0.18), text: tint(0.96, 0.08), subtext: tint(0.75, 0.08)
    };
}
