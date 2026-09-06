.pragma library

// Keep hue columns aligned across five shades, followed by a grayscale row.
function create() {
    var colors = [];
    var names = ["Red", "Orange", "Yellow", "Lime", "Green", "Mint",
                 "Cyan", "Sky blue", "Blue", "Purple", "Magenta", "Pink"];
    var lightness = [0.26, 0.40, 0.54, 0.70, 0.85];

    for (var row = 0; row < lightness.length; ++row) {
        for (var hue = 0; hue < names.length; ++hue) {
            colors.push({
                color: String(Qt.hsla(hue / names.length, 0.78, lightness[row], 1)),
                name: names[hue] + " · Shade " + (row + 1)
            });
        }
    }
    for (var gray = 0; gray < 12; ++gray) {
        colors.push({
            color: String(Qt.hsla(0, 0, gray / 11, 1)),
            name: "Gray · Shade " + (gray + 1)
        });
    }
    return colors;
}
