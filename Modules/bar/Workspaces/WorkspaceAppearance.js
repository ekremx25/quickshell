.pragma library

// Transparency changes the fill, never the selected shape or indicator.
function resolve(style, transparent, active) {
    var shape = style === "square" || style === "circle" || style === "outline";
    return {
        radius: style === "square" || style === "outline" ? 9 : 16,
        fill: !transparent && style !== "outline",
        borderWidth: shape ? (active ? 2 : 1) : 0,
        indicator: shape ? "" : style
    };
}
