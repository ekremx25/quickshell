.pragma library

var text = "#f5f7ff";
var subtext = "#aeb8cb";
var background = "#11141b";
var surface = "#171b24";
var overlay = "#6f7b91";
var overlay2 = "#8f9bb1";
var border = "#2d3544";
var card = "#171b24";
var cardStrong = "#232938";
var track = "#303848";

// Settings always uses a dark canvas, while Material You may expose very
// light or very dark accents. These helpers keep dynamic theme colors
// readable without discarding the selected scheme.
function _components(value) {
    if (typeof value === "string") {
        var hex = value.trim();
        if (hex.charAt(0) === "#") hex = hex.slice(1);
        if (hex.length === 3) {
            hex = hex.charAt(0) + hex.charAt(0)
                + hex.charAt(1) + hex.charAt(1)
                + hex.charAt(2) + hex.charAt(2);
        }
        if (hex.length === 6) {
            return {
                r: parseInt(hex.slice(0, 2), 16) / 255,
                g: parseInt(hex.slice(2, 4), 16) / 255,
                b: parseInt(hex.slice(4, 6), 16) / 255
            };
        }
    }
    return {
        r: value && value.r !== undefined ? value.r : 1,
        g: value && value.g !== undefined ? value.g : 1,
        b: value && value.b !== undefined ? value.b : 1
    };
}

function _linear(value) {
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}

function luminance(value) {
    var c = _components(value);
    return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
}

function contrast(first, second) {
    var a = luminance(first);
    var b = luminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

function readableAccent(candidate, canvas) {
    var target = canvas || background;
    return contrast(candidate, target) >= 3.0 ? candidate : text;
}

function foregroundFor(fill) {
    return contrast(text, fill) >= contrast(background, fill) ? text : background;
}

function withAlpha(value, alpha) {
    var c = _components(value);
    return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha)));
}
